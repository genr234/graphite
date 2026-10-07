<h1 align="center">Graphite</h1>

Printable pencil-and-dice notebook games

## Games

- **Golf:** 3 courses of 18 holes, in Parkland, Desert, Island or Plain themes
- **Dungeon:** 30 floors and 5 shops
- **Labyrinth:** a 50-room gamebook across 2 levels, mapped by the player

All games are solo and need one d6.

## Requirements

- [Gleam](https://gleam.run)
- Node.js 20.19+ or 22.12+
- [SWI-Prolog](https://www.swi-prolog.org) and [Typst](https://typst.app), for
  native rendering and tests

```bash
brew install gleam swi-prolog typst
```

## Build and run locally

```bash
npm install
npm run dev
```

Open http://localhost:5173. For a production build:

```bash
npm run build
npm run preview
```

## Render from the command line

```bash
scripts/render.sh golf my-seed us-letter parkland out/golf.pdf
```

| Argument | Values |
|---|---|
| `game` | `golf`, `dungeon`, `labyrinth` |
| `seed` | any string |
| `paper` | `a4` (default), `us-letter`, `pocket-a4` |
| `theme` | `parkland` (default), `desert`, `island`, `plain`. Golf only. |
| `output` | `out/<game>-<seed>-<theme>-<paper>.pdf` by default |

`pocket-a4` imposes A6 pages four to a side on A4. Print double-sided with a
long-edge flip, cut each sheet in half, nest the halves in order, then fold and
staple.

## Tests

```bash
swipl -g run_tests -t halt prolog/tests/graphite.plt
```

To report Dungeon balance (deaths, HP and shop affordability per floor):

```bash
swipl -q -g "balance_report([a, b, c], 4)" -t halt prolog/games/dungeon/simulate.pl
```

## Credits

- Pixel themes: [Kenney](https://kenney.nl) Tiny Town, Tiny Battle, Desert
  Shooter Pack and Monochrome Pirates (CC0). See
  [`LICENSE-kenney.txt`](typst/themes/LICENSE-kenney.txt) and each theme's
  `SOURCES.txt`.
- Labyrinth monsters: Kenney
  [Monster Builder Pack](https://kenney.nl/assets/monster-builder-pack) (CC0),
  in [`typst/monsters/`](typst/monsters/).
- UI icons: [pixelarticons](https://pixelarticons.com) by Gerrit Halfmann (MIT).
