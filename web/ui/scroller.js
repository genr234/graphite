// <graphite-scroller>: the preview tray's scroll area, with a page rail in
// place of the native scrollbar. See web/ui/README.md.
//
// The rail is a slider fader: one tick per page of the slotted Typst SVG, a
// longer tick and an engraved caption wherever the game starts a section,
// and a flag naming the page under the pointer. Clicking the rail or pressing
// PageUp/PageDown lands on a whole page; Shift jumps a section.
//
// Attributes:
//   stops  JSON list of { page, label, short, group, mark } that the game's
//          template marks with `<stop>` metadata (see typst/golf.typ).
//   busy   present while a new preview is being generated.

import css from "./scroller.css?inline";

const styles = new CSSStyleSheet();
styles.replaceSync(css);

const motion = matchMedia("(prefers-reduced-motion: reduce)");

// A page counts as current once its top passes this far down the view.
const FOCUS = 0.35;
// Breathing room left above a page when jumping to it.
const LEAD = 16;
const MIN_THUMB = 36;

class GraphiteScroller extends HTMLElement {
  static observedAttributes = ["stops"];

  #stops = [];
  #pages = []; // { top, mark, stop } per page, top in scroll coordinates
  #ticks = []; // tick centre within the track, per page
  #thumb = 0;
  #range = 0;
  #current = -1;
  #hover = -1;
  #drag = null;
  #frame = 0;
  #fade = 0;

  constructor() {
    super();
    const root = this.attachShadow({ mode: "open" });
    root.adoptedStyleSheets = [styles];
    root.innerHTML = `
      <div class="viewport" part="viewport" tabindex="0" role="region" aria-label="Preview">
        <slot></slot>
      </div>
      <div class="lip"></div>
      <div class="busy" aria-hidden="true">
        <div class="blank"><i></i><i></i><i></i><i></i></div>
        <div class="panel">
          <span class="label">Generating</span>
          <span class="feed"><i></i></span>
        </div>
      </div>
      <div class="flag" aria-hidden="true"><small></small><b></b><em></em></div>
      <div class="rail" aria-hidden="true">
        <div class="track">
          <div class="slot"></div>
          <div class="ticks"></div>
          <div class="thumb"></div>
        </div>
      </div>`;
    this.$ = Object.fromEntries(
      ["viewport", "flag", "rail", "track", "ticks", "thumb"].map((name) => [
        name,
        root.querySelector(`.${name}`),
      ]),
    );

    const { viewport, rail, track, thumb } = this.$;
    viewport.addEventListener("scroll", () => this.#schedule(true), { passive: true });
    viewport.addEventListener("keydown", (event) => this.#key(event));
    rail.addEventListener("wheel", (event) => this.#wheel(event), { passive: false });
    track.addEventListener("pointermove", (event) => this.#point(event));
    track.addEventListener("pointerleave", () => this.#point(null));
    track.addEventListener("pointerdown", (event) => this.#press(event));
    thumb.addEventListener("pointermove", (event) => this.#dragTo(event));
    thumb.addEventListener("pointerup", (event) => this.#release(event));
    thumb.addEventListener("lostpointercapture", (event) => this.#release(event));

    this.resizes = new ResizeObserver(() => this.#measure());
    this.mutations = new MutationObserver(() => this.#measure());
  }

  connectedCallback() {
    this.resizes.observe(this.$.viewport);
    this.resizes.observe(this.$.track);
    this.mutations.observe(this, { childList: true, subtree: true });
    this.#measure();
  }

  disconnectedCallback() {
    this.resizes.disconnect();
    this.mutations.disconnect();
    cancelAnimationFrame(this.#frame);
  }

  attributeChangedCallback(_name, _old, value) {
    try {
      this.#stops = JSON.parse(value || "[]").sort((a, b) => a.page - b.page);
    } catch {
      this.#stops = [];
    }
    this.#measure();
  }

  // Layout ----------------------------------------------------------------

  #measure() {
    const { viewport } = this.$;
    const svg = this.querySelector("svg");
    if (svg) this.resizes.observe(svg);
    const groups = svg ? [...svg.querySelectorAll(".typst-page")] : [];
    this.toggleAttribute("empty", groups.length === 0);

    if (groups.length) {
      const box = svg.getBoundingClientRect();
      const scale = box.height / svg.viewBox.baseVal.height;
      const origin = box.top - viewport.getBoundingClientRect().top + viewport.scrollTop;
      let s = -1;
      this.#pages = groups.map((group, i) => {
        while (this.#stops[s + 1]?.page <= i + 1) s++;
        const stop = this.#stops[s];
        const starts = stop?.page === i + 1;
        const y = group.transform.baseVal.consolidate()?.matrix.f ?? 0;
        return {
          top: Math.max(0, origin + y * scale - LEAD),
          stop,
          mark: starts ? stop.mark : "continued",
        };
      });
    } else {
      this.#pages = [];
    }
    this.#layoutRail();
  }

  #layoutRail() {
    const { viewport, track, ticks } = this.$;
    const max = viewport.scrollHeight - viewport.clientHeight;
    const height = track.clientHeight;
    this.toggleAttribute("static", max <= 1 || this.#pages.length < 2);

    this.#thumb = Math.min(height, Math.max(MIN_THUMB, (height * viewport.clientHeight) / viewport.scrollHeight));
    this.#range = height - this.#thumb;
    this.#ticks = this.#pages.map(
      ({ top }) => this.#thumb / 2 + (max > 0 ? (this.#range * Math.min(top, max)) / max : 0),
    );
    this.$.thumb.style.height = `${this.#thumb}px`;

    ticks.replaceChildren(
      ...this.#pages.map(({ mark, stop }, i) => {
        const tick = document.createElement("span");
        tick.className = `tick tick--${mark}`;
        tick.style.top = `${this.#ticks[i]}px`;
        if (mark === "major" && stop.short) tick.dataset.short = stop.short;
        if (i === this.#hover) tick.classList.add("is-hover");
        return tick;
      }),
    );
    this.#current = -1;
    this.#schedule(false);
  }

  // Scrolling -------------------------------------------------------------

  #schedule(scrolled) {
    if (scrolled && this.#hover < 0) this.#reveal();
    if (this.#frame) return;
    this.#frame = requestAnimationFrame(() => {
      this.#frame = 0;
      this.#sync();
    });
  }

  #sync() {
    const { viewport, thumb } = this.$;
    const max = viewport.scrollHeight - viewport.clientHeight;
    const at = max > 0 ? viewport.scrollTop / max : 0;
    thumb.style.transform = `translateY(${this.#range * at}px)`;

    const current = this.#pageAt(viewport.scrollTop, max);
    if (current !== this.#current) {
      this.$.ticks.children[this.#current]?.classList.remove("is-current");
      this.$.ticks.children[current]?.classList.add("is-current");
      this.#current = current;
    }
    if (this.#hover < 0 && this.hasAttribute("scrolling")) {
      this.#flag(current, this.#thumb / 2 + this.#range * at);
    }
  }

  #pageAt(scrollTop, max) {
    if (scrollTop >= max - 1) return this.#pages.length - 1;
    const line = scrollTop + this.$.viewport.clientHeight * FOCUS;
    let i = 0;
    while (this.#pages[i + 1]?.top <= line) i++;
    return this.#pages.length ? i : -1;
  }

  #jump(index) {
    const page = this.#pages[Math.max(0, Math.min(index, this.#pages.length - 1))];
    if (!page) return;
    this.$.viewport.scrollTo({ top: page.top, behavior: motion.matches ? "auto" : "smooth" });
  }

  // The first page of the next (step 1) or current/previous (step -1) section.
  #section(step) {
    const major = (i) => this.#pages[i]?.mark === "major";
    let i = this.#current + step;
    while (i > 0 && i < this.#pages.length - 1 && !major(i)) i += step;
    return i;
  }

  #key(event) {
    if (event.altKey || event.ctrlKey || event.metaKey) return;
    const step = { PageDown: 1, PageUp: -1 }[event.key];
    if (!step || !this.#pages.length) return;
    event.preventDefault();
    this.#jump(event.shiftKey ? this.#section(step) : this.#current + step);
  }

  #wheel(event) {
    event.preventDefault();
    const unit = [1, 16, this.$.viewport.clientHeight][event.deltaMode];
    this.$.viewport.scrollBy({ top: event.deltaY * unit });
  }

  // Rail pointer ----------------------------------------------------------

  #trackY(event) {
    return event.clientY - this.$.track.getBoundingClientRect().top;
  }

  #nearest(y) {
    let best = -1;
    let distance = Infinity;
    this.#ticks.forEach((tick, i) => {
      const d = Math.abs(tick - y);
      if (d < distance) [best, distance] = [i, d];
    });
    return best;
  }

  #point(event) {
    if (this.#drag) return;
    const index = event && !event.target.closest(".thumb") ? this.#nearest(this.#trackY(event)) : -1;
    if (index === this.#hover) return;
    this.$.ticks.children[this.#hover]?.classList.remove("is-hover");
    this.#hover = index;
    if (index < 0) return this.#conceal(0);
    this.$.ticks.children[index]?.classList.add("is-hover");
    this.#flag(index, this.#ticks[index]);
    this.#reveal(false);
  }

  #press(event) {
    if (event.button !== 0) return;
    event.preventDefault();
    if (!event.target.closest(".thumb")) {
      this.#jump(this.#nearest(this.#trackY(event)));
      return;
    }
    this.$.thumb.setPointerCapture(event.pointerId);
    this.#drag = { y: event.clientY, top: this.$.viewport.scrollTop };
    this.toggleAttribute("dragging", true);
    this.#reveal(false);
    this.#point(null);
    this.#schedule(true);
  }

  #dragTo(event) {
    if (!this.#drag || !this.#range) return;
    const { viewport } = this.$;
    const max = viewport.scrollHeight - viewport.clientHeight;
    viewport.scrollTop = this.#drag.top + ((event.clientY - this.#drag.y) * max) / this.#range;
  }

  #release(event) {
    if (!this.#drag) return;
    this.#drag = null;
    if (this.$.thumb.hasPointerCapture(event.pointerId)) {
      this.$.thumb.releasePointerCapture(event.pointerId);
    }
    this.toggleAttribute("dragging", false);
    this.#conceal();
  }

  // Flag ------------------------------------------------------------------

  #flag(index, y) {
    const page = this.#pages[index];
    if (!page) return;
    const { flag, rail, track } = this.$;
    const [group, label, count] = flag.children;
    group.textContent = page.stop?.group ?? "";
    label.textContent = page.stop?.label ?? `Page ${index + 1}`;
    count.textContent = `${index + 1}/${this.#pages.length}`;
    // Keep the flag inside the tray, even for ticks near its ends.
    const half = flag.offsetHeight / 2 + 6;
    const top = rail.offsetTop + track.offsetTop + y;
    flag.style.top = `${Math.min(Math.max(top, half), this.clientHeight - half)}px`;
  }

  // Show the flag; while scrolling (sticky = true) it fades shortly after.
  #reveal(sticky = true) {
    clearTimeout(this.#fade);
    this.toggleAttribute("scrolling", true);
    if (sticky && !this.#drag) this.#conceal();
  }

  #conceal(delay = 700) {
    clearTimeout(this.#fade);
    this.#fade = setTimeout(() => {
      if (this.#drag || this.#hover >= 0) return;
      this.toggleAttribute("scrolling", false);
    }, delay);
  }
}

customElements.get("graphite-scroller") ?? customElements.define("graphite-scroller", GraphiteScroller);
