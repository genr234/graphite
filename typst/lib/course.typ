// Draws one GOLF hole: terrain tiles, wash, grid, then tee, cup, slopes and Bigfoot.

#let plain-fill = (
  r: white,
  f: rgb("#e3f1d8"),
  s: rgb("#f4e7c4"),
  w: rgb("#d4e6f5"),
  t: white,
)

#let tile(theme, name, cell, angle: 0deg) = {
  let img = image(theme.dir + name + ".png", width: cell, height: cell, scaling: "pixelated")
  if angle == 0deg { img } else { rotate(angle, reflow: false, img) }
}

// Stable per-cell variant choice, so tiles don't repeat in obvious stripes.
#let pick(variants, x, y) = variants.at(calc.rem(x * 7 + y * 13 + calc.rem(x * y, 5), variants.len()))

// Autotile: choose the edge piece from which orthogonal neighbours are the
// same terrain. The grid border counts as "same" so shapes run off the edge.
// Shapes one cell thin have no matching piece, so that axis uses the centre.
#let edge-name(base, same) = {
  let v = if same.n == same.s { "" } else if not same.n { "n" } else { "s" }
  let h = if same.w == same.e { "" } else if not same.w { "w" } else { "e" }
  let dir = v + h
  base + "-" + if dir == "" { "c" } else { dir }
}

#let slope-angle = (n: 0deg, e: 90deg, s: 180deg, w: 270deg)

// A single framed cell of terrain, for legends.
#let swatch(theme, code, size) = box(width: size, height: size, stroke: 0.6pt + theme.ink, {
  if theme.terrain == none {
    place(rect(width: size, height: size, fill: plain-fill.at(code), stroke: none))
  } else {
    let spec = theme.terrain.at(code)
    let name = if type(spec) == dictionary { spec.autotile + "-c" } else { spec.at(0) }
    place(tile(theme, name, size))
    let stripes = theme.at("stripes", default: (:))
    if code in stripes {
      place(rect(width: size, height: size, stroke: none,
                 fill: white.transparentize(stripes.at(code).at(0))))
    }
  }
  if code in theme.over { place(tile(theme, theme.over.at(code).at(0), size)) }
})

#let hole-map(hole, theme, cell) = {
  let grid = hole.rows.map(r => r.clusters())
  let (w, h) = (hole.width, hole.height)
  let code(x, y) = if x < 0 or y < 0 or x >= w or y >= h { none } else { grid.at(y).at(x) }
  let same(x, y, c) = {
    let n = code(x, y)
    n == none or n == c
  }
  let at(x, y, body) = place(dx: x * cell, dy: y * cell, body)

  box(width: w * cell, height: h * cell, {
    // Terrain.
    for y in range(h) {
      for x in range(w) {
        let c = grid.at(y).at(x)
        if theme.terrain == none {
          at(x, y, rect(width: cell, height: cell, fill: plain-fill.at(c), stroke: none))
        } else {
          let spec = theme.terrain.at(c)
          let name = if type(spec) == dictionary {
            edge-name(spec.autotile, (
              n: same(x, y - 1, c), s: same(x, y + 1, c),
              w: same(x - 1, y, c), e: same(x + 1, y, c),
            ))
          } else { pick(spec, x, y) }
          at(x, y, tile(theme, name, cell))
          let stripes = theme.at("stripes", default: (:))
          if c in stripes {
            let shades = stripes.at(c)
            at(x, y, rect(width: cell, height: cell, stroke: none,
                          fill: white.transparentize(shades.at(calc.rem(y, shades.len())))))
          }
        }
        if c in theme.over {
          at(x, y, tile(theme, pick(theme.over.at(c), x, y), cell))
        }
      }
    }

    if theme.wash > 0% {
      place(rect(width: w * cell, height: h * cell, stroke: none,
                 fill: white.transparentize(100% - theme.wash)))
    }

    // Grid.
    for x in range(w + 1) {
      place(line(start: (x * cell, 0pt), end: (x * cell, h * cell), stroke: 0.4pt + theme.line))
    }
    for y in range(h + 1) {
      place(line(start: (0pt, y * cell), end: (w * cell, y * cell), stroke: 0.4pt + theme.line))
    }

    // Markers.
    for s in hole.slopes {
      at(s.x, s.y, tile(theme, theme.arrow, cell, angle: slope-angle.at(s.dir)))
    }
    let (tx, ty) = hole.tee
    at(tx, ty, tile(theme, theme.tee, cell))
    let (cx, cy) = hole.cup
    at(cx, cy, tile(theme, theme.cup, cell))
    if "bigfoot" in hole {
      let (bx, by) = hole.bigfoot
      at(bx, by, tile(theme, theme.bigfoot, cell))
    }

    place(rect(width: w * cell, height: h * cell, stroke: 0.8pt + theme.ink))
  })
}
