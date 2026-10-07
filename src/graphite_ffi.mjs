import { Ok, Error } from "./gleam.mjs";
import { tileUrl } from "/web/tiles.js";

// The engine spawns the Prolog worker and loads Typst WASM, so it's only
// imported once a generator opens; the home page stays light.
const engine = () => import("/web/engine.js");

function settle(promise, callback) {
  promise.then(
    (value) => callback(new Ok(value)),
    (error) => callback(new Error(String(error?.message ?? error))),
  );
}

export function preview(game, seed, paper, theme, callback) {
  settle(
    engine().then(async ({ generate, preview }) => {
      const { svg, stops } = await preview(game, await generate(game, seed), paper, theme);
      return [svg, JSON.stringify(stops)];
    }),
    callback,
  );
}

export function download_pdf(game, seed, paper, theme, callback) {
  const work = engine().then(async ({ generate, pdf }) => {
    const bytes = await pdf(game, await generate(game, seed), paper, theme);
    const url = URL.createObjectURL(new Blob([bytes], { type: "application/pdf" }));
    const link = document.createElement("a");
    link.href = url;
    link.download = `${game}-${seed}-${theme}.pdf`;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    return undefined;
  });
  settle(work, callback);
}

// Routing -------------------------------------------------------------------

// "#/golf" -> "golf"; "", "#" and "#/" -> "".
export function current_hash() {
  return location.hash.replace(/^#\/?/, "");
}

export function on_hash_change(callback) {
  addEventListener("hashchange", () => callback(current_hash()));
}

export function tile_url(theme, name) {
  return tileUrl(theme, name);
}

// Updates the address bar without adding history or firing hashchange.
export function replace_hash(hash) {
  history.replaceState(history.state, "", `#${hash}`);
}

export function scroll_top() {
  scrollTo({ top: 0 });
}
