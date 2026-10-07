# Graphite

Printable pen-and-dice notebook games, procedurally generated from a seed.

- **Generators:** SWI-Prolog (`prolog/`), running in the browser via swipl-wasm.
- **Layout:** Typst (`typst/`), compiled to SVG/PDF in the browser via typst.ts.
- **UI:** Gleam + Lustre (`src/`).

## Requirements

Gleam, Node.js, plus SWI-Prolog and Typst for the native tools
(`brew install gleam swi-prolog typst`).

## Develop

```sh
npm install
npm run dev          # http://localhost:5173
```

## Native render

```sh
scripts/render.sh golf my-seed us-letter parkland out/golf.pdf
```

Paper is `a4`, `us-letter`, or `pocket-a4`: A6 pages imposed four to a side on
A4, to print double-sided (long-edge flip), cut in half, nest and fold into a
pocket booklet. The same seed produces the same notebook natively and in the
browser.

## Themes

Pixel themes use tiles from [Kenney](https://kenney.nl)'s CC0 packs (Tiny Town,
Tiny Battle, Desert Shooter Pack, Monochrome Pirates). See
`typst/themes/LICENSE-kenney.txt` and each theme's `SOURCES.txt`.

LABYRINTH's random monsters are put together from Kenney's
[Monster Builder Pack](https://kenney.nl/assets/monster-builder-pack) (CC0),
in `typst/monsters/`.

UI icons are [pixelarticons](https://pixelarticons.com) (MIT, Gerrit Halfmann),
compiled in by `scripts/icons.mjs`.

## Test

```sh
swipl -g run_tests -t halt prolog/tests/graphite.plt
```
