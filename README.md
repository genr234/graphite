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
scripts/render.sh golf my-seed us-letter out/golf.pdf
```

The same seed produces the same notebook natively and in the browser.

## Test

```sh
swipl -g run_tests -t halt prolog/tests/graphite.plt
```
