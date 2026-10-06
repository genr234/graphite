// Shared drawing blocks for grid-based titles.
// Placeholder styling: plain fills and shapes until the real assets land.

#let ink = luma(40)
#let faint = luma(170)

#let terrain-style = (
  r: (fill: white, mark: none),
  f: (fill: rgb("#e3f1d8"), mark: none),
  s: (fill: rgb("#f4e7c4"), mark: "sand"),
  w: (fill: rgb("#d4e6f5"), mark: "water"),
  t: (fill: white, mark: "tree"),
)

#let mark(kind, size) = {
  if kind == "tree" {
    circle(radius: size * 0.3, fill: rgb("#7aa36b"), stroke: 0.5pt + ink)
  } else if kind == "water" {
    line(start: (-size * 0.25, 0pt), end: (size * 0.25, 0pt), stroke: 0.5pt + rgb("#6c9cc4"))
  } else if kind == "sand" {
    circle(radius: size * 0.04, fill: rgb("#b89b5e"), stroke: none)
  }
}

// rows: array of strings, one char per cell (see prolog/games/golf.pl).
// tee, cup: (x, y) cell coordinates, origin top-left.
#let terrain-grid(rows, tee: none, cup: none, cell: 1.3cm) = {
  let cells = ()
  for (y, row) in rows.enumerate() {
    for (x, code) in row.clusters().enumerate() {
      let style = terrain-style.at(code)
      let body = if (x, y) == (tee.at(0), tee.at(1)) {
        text(weight: "bold", fill: ink)[T]
      } else if (x, y) == (cup.at(0), cup.at(1)) {
        circle(radius: cell * 0.18, fill: ink)
      } else if style.mark != none {
        mark(style.mark, cell)
      }
      cells.push(grid.cell(fill: style.fill, align(center + horizon, body)))
    }
  }
  grid(
    columns: (cell,) * rows.at(0).clusters().len(),
    rows: (cell,) * rows.len(),
    inset: 0pt,
    stroke: 0.4pt + faint,
    ..cells,
  )
}
