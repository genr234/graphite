#import "lib/grid.typ": terrain-grid, ink, faint

// Notebook data comes from prolog/graphite.pl as a JSON string input.
#let data = json(bytes(sys.inputs.data))

#set page(
  paper: sys.inputs.at("paper", default: "a4"),
  margin: (x: 1.5cm, y: 1.8cm),
  footer: context {
    set text(8pt, fill: faint)
    [seed #data.seed]
    h(1fr)
    counter(page).display()
  },
)
#set text(size: 10pt, fill: ink)

#for (i, hole) in data.holes.enumerate() {
  if i > 0 { pagebreak() }
  grid(
    columns: (1fr, auto),
    text(18pt, weight: "bold")[Hole #hole.number],
    text(12pt)[Par #hole.par #h(1em) Strokes #box(width: 2cm, stroke: (bottom: 0.5pt + ink))],
  )
  v(0.6cm)
  align(center, terrain-grid(hole.rows, tee: hole.tee, cup: hole.cup))
}
