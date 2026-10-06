// Visual themes. Tiles are Kenney pixel art (CC0, see themes/LICENSE-kenney.txt),
// plus a few original pixel sprites where a pack lacks a piece
// (per-theme SOURCES.txt). A theme only changes the look; the course is the same.
//
// terrain: per terrain code, either an array of tile variants (picked per cell)
//          or (autotile: "name"), a 3x3 edge set name-nw … name-se.
//          `none` draws flat colour fills instead (the ink-saving theme).
// tee, cup, arrow, bigfoot: marker sprites (the arrow points up).
// over:    sprites drawn on top of the base terrain (trees on rough).
// stripes: per terrain code, white overlays alternating by row (mowing lines).
// wash:    white overlay so pencil lines stay readable on busy tiles.

#let themes = (
  plain: (
    name: "Plain",
    dir: "/themes/plain/",
    terrain: none,
    over: (t: ("tree",)),
    tee: "tee",
    cup: "flag",
    arrow: "arrow",
    bigfoot: "bigfoot",
    ink: luma(40),
    line: luma(170),
    wash: 0%,
  ),
  parkland: (
    name: "Parkland",
    dir: "/themes/parkland/",
    terrain: (
      r: ("rough-1", "rough-1", "rough-1", "rough-2"),
      f: ("fairway",),
      s: (autotile: "sand"),
      w: (autotile: "water"),
      t: ("rough-1",),
    ),
    over: (t: ("tree-1", "tree-2", "tree-3")),
    stripes: (f: (55%, 70%)),
    tee: "tee",
    cup: "flag",
    arrow: "arrow",
    bigfoot: "bigfoot",
    ink: rgb("#3b2a33"),
    line: rgb("#2f5130").transparentize(55%),
    wash: 20%,
  ),
  desert: (
    name: "Desert",
    dir: "/themes/desert/",
    terrain: (
      r: ("rough-1", "rough-1", "rough-2"),
      f: (autotile: "fairway"),
      s: ("sand-1", "sand-2", "sand-3"),
      w: (autotile: "water"),
      t: ("rough-1",),
    ),
    over: (t: ("tree-1", "tree-2", "tree-3", "tree-4")),
    tee: "tee",
    cup: "flag",
    arrow: "arrow",
    bigfoot: "bigfoot",
    ink: rgb("#3a2e3f"),
    line: rgb("#7a5a3a").transparentize(55%),
    wash: 20%,
  ),
  island: (
    name: "Island",
    dir: "/themes/island/",
    terrain: (
      r: ("rough-1",),
      f: ("fairway",),
      s: ("sand-1",),
      w: ("water-1", "water-2"),
      t: ("rough-1",),
    ),
    over: (t: ("tree-1", "tree-2", "tree-3")),
    tee: "tee",
    cup: "flag",
    arrow: "arrow",
    bigfoot: "bigfoot",
    ink: black,
    line: luma(150),
    wash: 0%,
  ),
)

#let theme-names = themes.keys()
