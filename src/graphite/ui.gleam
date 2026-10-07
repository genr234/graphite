//// View helpers for the Graphite design system (web/ui/). Build controls
//// through these rather than raw html so markup and CSS stay in step.

import gleam/list
import gleam/option.{type Option, None, Some}
import graphite/icons.{type Icon}
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg
import lustre/event

/// A raised key. Pass `signal_key` instead for the panel's one main action.
pub fn key(
  label: String,
  on_press: msg,
  icon icon: Option(Icon),
  attrs attrs: List(Attribute(msg)),
) -> Element(msg) {
  html.button(
    [attribute.class("key"), event.on_click(on_press), ..attrs],
    key_face(icon, label),
  )
}

/// The orange key. Use at most one per panel.
pub fn signal_key(
  label: String,
  on_press: msg,
  icon icon: Option(Icon),
  enabled enabled: Bool,
) -> Element(msg) {
  html.button(
    [
      attribute.class("key key--signal"),
      attribute.disabled(!enabled),
      event.on_click(on_press),
    ],
    key_face(icon, label),
  )
}

fn key_face(icon: Option(Icon), label: String) -> List(Element(msg)) {
  case icon {
    Some(icon) -> [view_icon(icon), html.text(label)]
    None -> [html.text(label)]
  }
}

/// A round key seated in a bezel, showing a single icon.
pub fn round_key(icon: Icon, label: String, on_press: msg) -> Element(msg) {
  html.span([attribute.class("bezel")], [
    html.button(
      [
        attribute.class("key key--round"),
        attribute.aria_label(label),
        attribute.title(label),
        event.on_click(on_press),
      ],
      [view_icon(icon)],
    ),
  ])
}

/// The orange key as a link, for main actions that navigate.
pub fn signal_link(
  label: String,
  href: String,
  icon: Option(Icon),
) -> Element(msg) {
  html.a(
    [attribute.class("key key--signal"), attribute.href(href)],
    key_face(icon, label),
  )
}

/// A round key in a bezel that navigates, such as "back".
pub fn round_link(icon: Icon, label: String, href: String) -> Element(msg) {
  html.span([attribute.class("bezel")], [
    html.a(
      [
        attribute.class("key key--round"),
        attribute.href(href),
        attribute.aria_label(label),
        attribute.title(label),
      ],
      [view_icon(icon)],
    ),
  ])
}

/// A row of latching keys; the selected one sits down.
pub fn bank(
  label: String,
  options: List(#(String, String)),
  selected: String,
  on_select: fn(String) -> msg,
) -> Element(msg) {
  html.div(
    [
      attribute.role("radiogroup"),
      attribute.aria_label(label),
      attribute.class("bank"),
    ],
    {
      use #(value, caption) <- list.map(options)
      let checked = value == selected
      html.button(
        [
          attribute.class("key"),
          attribute.role("radio"),
          attribute.aria_checked(case checked {
            True -> "true"
            False -> "false"
          }),
          event.on_click(on_select(value)),
        ],
        [html.text(caption)],
      )
    },
  )
}

/// An engraved caption above a control.
pub fn field(label: String, children: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("field")], [
    html.span([attribute.class("label")], [html.text(label)]),
    ..children
  ])
}

/// A smoked-glass text display.
pub fn readout(
  value: String,
  label: String,
  on_input: fn(String) -> msg,
  attrs: List(Attribute(msg)),
) -> Element(msg) {
  html.span([attribute.class("readout")], [
    html.input([
      attribute.value(value),
      attribute.aria_label(label),
      attribute.spellcheck(False),
      attribute.autocomplete("off"),
      event.on_input(on_input),
      ..attrs
    ]),
  ])
}

/// An engraved status caption.
pub fn status(caption: String) -> Element(msg) {
  html.span([attribute.class("label status"), attribute.role("status")], [
    html.text(caption),
  ])
}

// NOTEBOOKS -------------------------------------------------------------------

/// A pocket notebook that opens `href`: a cover scene, a paper label and an
/// elastic band. The whole notebook is the link.
pub fn notebook(
  title: String,
  number: String,
  cover: Element(msg),
  href: String,
) -> Element(msg) {
  html.a(
    [
      attribute.class("notebook"),
      attribute.href(href),
      attribute.aria_label("Open " <> title <> " notebook number " <> number),
    ],
    [
      html.span([attribute.class("notebook-cover")], [cover]),
      html.span([attribute.class("notebook-label")], [
        html.span([attribute.class("notebook-title")], [html.text(title)]),
        html.span([attribute.class("notebook-number")], [
          html.text("№ " <> number),
        ]),
      ]),
      html.span([attribute.class("notebook-band")], []),
    ],
  )
}

/// The notebooks, laid out on the page. A single one is shown larger.
pub fn shelf(items: List(Element(msg))) -> Element(msg) {
  html.ul([attribute.class("shelf")], items)
}

pub fn shelf_item(notebook: Element(msg)) -> Element(msg) {
  html.li([attribute.class("shelf-item")], [notebook])
}

// SCROLLER --------------------------------------------------------------------

/// The preview's scroll area (web/ui/scroller.js), with a page rail in place
/// of the native scrollbar. `stops` is the JSON page outline from the game
/// template; `busy` shows the generating overlay.
pub fn scroller(
  stops: String,
  busy busy: Bool,
  children children: List(Element(msg)),
) -> Element(msg) {
  element.element(
    "graphite-scroller",
    [
      attribute.attribute("stops", stops),
      case busy {
        True -> attribute.attribute("busy", "")
        False -> attribute.none()
      },
      attribute.aria_busy(busy),
    ],
    children,
  )
}

// ICONS -----------------------------------------------------------------------

/// A pixelarticons glyph. Add new ones in scripts/icons.mjs.
pub fn view_icon(icon: Icon) -> Element(msg) {
  svg.svg(
    [
      attribute.class("icon"),
      attribute.attribute("viewBox", "0 0 24 24"),
      attribute.aria_hidden(True),
    ],
    [svg.path([attribute.attribute("d", icons.path(icon))])],
  )
}
