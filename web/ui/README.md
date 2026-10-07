# Graphite UI

A skeuomorphic design system in the spirit of 1960s–70s Braun hardware: the
app is a device lit from above, made of a few physical materials.

| Depth    | Class      | Used for                                      |
| -------- | ---------- | --------------------------------------------- |
| Raised   | `.key`     | Anything you press                            |
| Flush    | `.plate`   | Panels fixed onto the chassis                 |
| Recessed | `.well`, `.bezel`, `.readout` | Inputs, trays, seats for keys |

## Rules

- **One material per job.** Keys press, wells hold, plates group. Don't put a
  shadow on anything that isn't one of these.
- **Colour is a signal.** The UI is greyscale. Orange (`.key--signal`) marks
  the panel's single main action, and red marks errors.
- **Labels are engraved.** Captions use `.label`: small, uppercase, tracked,
  with a highlight beneath (or a shadow above in dark mode).
- **State is physical.** A selected or latched key sits down
  (`aria-checked`/`aria-pressed="true"`), and a disabled key loses its depth.
- **Tokens only.** `controls.css` and app styles use the variables in
  `tokens.css`. Dark mode ("graphite") swaps colours, and the depth recipes
  (`--raised`, `--recessed`, …) adapt on their own.

## Controls

| Control       | Markup                                   | Gleam (`graphite/ui`) |
| ------------- | ---------------------------------------- | --------------------- |
| Key           | `button.key`                             | `ui.key`              |
| Signal key    | `button.key.key--signal`                 | `ui.signal_key`       |
| Round key     | `.bezel > button.key.key--round` + icon  | `ui.round_key`        |
| Key in bezel  | `.bezel > button.key`                    | wrap in `span.bezel`  |
| Bank          | `.bank[role=radiogroup] > .key[role=radio]` | `ui.bank`          |
| Readout       | `.readout > input`                       | `ui.readout`          |
| Status        | `span.label.status[role=status]`         | `ui.status`           |
| Field caption | `.field > .label + control`              | `ui.field`            |
| Page scroller | `graphite-scroller[stops][busy]`         | `ui.scroller`         |

### Page scroller

`<graphite-scroller>` (`scroller.js`) is the preview tray's scroll area. It
hides the native scrollbar and draws a slider rail instead: one tick per page
of the Typst SVG it wraps, a long tick and caption where a section starts, and
a readout flag naming the page under the pointer (or the current page while
scrolling). Clicking the rail, PageUp and PageDown land on whole pages; Shift
jumps a section. With `busy` it dims the sheet and shows a "Generating" plate,
or a blank sheet before the first preview.

Each game decides its own sections: its template marks pages with
`<stop>` metadata `(page, label, short, group, mark)`, and the engine queries
them alongside the SVG (see `stop` in `typst/golf.typ`).
| Signal link   | `a.key.key--signal`                      | `ui.signal_link`      |
| Round link    | `.bezel > a.key.key--round` + icon       | `ui.round_link`       |
| Notebook      | `a.notebook` (cover, label, band)        | `ui.notebook`         |
| Shelf         | `ul.shelf > li.shelf-item`               | `ui.shelf`, `ui.shelf_item` |

## Notebooks and the shelf

`notebook.css` draws a pocket notebook: a pixel cover scene
(`graphite/cover`), a paper label that stays light in dark mode, an elastic
band and stacked page edges. Covers are 7 × 10 tiles of 16px art, so the size
is set by `--tile`, which must be a multiple of 16 (32px on the grid, 48px as a
feature) to keep every pixel square.

The shelf is just the notebooks on the bare page: no tray, captions or text.
A single notebook is shown at the feature size and several form a grid. This
is pure CSS (`:only-child`), so the Gleam doesn't branch on the count.

## Icons

Icons come from [pixelarticons](https://pixelarticons.com) (MIT). Only the
ones the app uses are compiled in: list a name from
`node_modules/pixelarticons/svg/` in `scripts/icons.mjs`, then run
`node scripts/icons.mjs` to regenerate `src/graphite/icons.gleam`. Render them
with `ui.view_icon`, or pass `icon: Some(icons.X)` to `ui.key` or
`ui.signal_key`. Pixel icons always render at 24px (`.icon`) so every pixel
lands on a device pixel; don't scale them to other sizes.
