// DUNGEON: one page per floor, shops between floors, then the treasure and the stats.

// Notebook data comes from prolog/graphite.pl as a JSON string input.
#let data = json(bytes(sys.inputs.data))
#let paper = sys.inputs.at("paper", default: "a4")
#let ink = luma(30)
#let faint = luma(150)
#let soft = luma(228)
#let stone = luma(200)
#let stone-dark = luma(178)
#let mono = "DejaVu Sans Mono"

// Pocket (A6) pages get imposed into a booklet by impose.typ. Spacing scales
// by `k` and text by `kt`, as in golf.typ.
#let pocket = paper == "a6"
#let k = if pocket { 0.6 } else { 1 }
#let kt = if pocket { 0.75 } else { 1 }

#set page(
  paper: paper,
  fill: white,
  margin: if pocket { (x: 6mm, top: 6mm, bottom: 9mm) } else { (x: 1.8cm, top: 1.5cm, bottom: 1.6cm) },
  footer: context {
    set text(7pt * kt, fill: faint)
    [DUNGEON · seed #data.seed]
    h(1fr)
    counter(page).display()
  },
)
#set text(size: 10pt * kt, fill: ink)

#let title(size, body) = text(size * kt, font: mono, weight: "bold", body)
#let label(size, body, fill: ink) = text(size * kt, font: mono, weight: "bold", fill: fill, body)

// Preview outline for the app's page rail (web/ui/scroller.js).
#let stop(label, short, group: none, mark: "minor") = context [
  #metadata((page: here().page(), label: label, short: short, group: group, mark: mark)) <stop>
]

// Icons -------------------------------------------------------------------------
// Each draws into an s × s box.

#let heart-shape(s, fill: white, stroke: ink, thickness: none) = curve(
  fill: fill, stroke: (paint: stroke, thickness: if thickness == none { s * 0.07 } else { thickness }, join: "round"),
  curve.move((0.5 * s, 0.92 * s)),
  curve.cubic((0.38 * s, 0.8 * s), (0.04 * s, 0.6 * s), (0.06 * s, 0.36 * s)),
  curve.cubic((0.08 * s, 0.12 * s), (0.42 * s, 0.06 * s), (0.5 * s, 0.28 * s)),
  curve.cubic((0.58 * s, 0.06 * s), (0.92 * s, 0.12 * s), (0.94 * s, 0.36 * s)),
  curve.cubic((0.96 * s, 0.6 * s), (0.62 * s, 0.8 * s), (0.5 * s, 0.92 * s)),
  curve.close(),
)

#let centred(s, body, dy: 0pt) = place(dy: dy, box(width: s, height: s, align(center + horizon, body)))

#let number(s, value, fill: ink, scale: 0.42) = text(s * scale, font: mono, weight: "bold", fill: fill,
  if value == none { "?" } else { str(value) })

#let heart(s, value) = box(width: s, height: s, {
  place(heart-shape(s))
  centred(s, number(s, value, scale: 0.36), dy: -s * 0.04)
})

// A horned blob with its strength on its belly.
#let enemy(s, value) = box(width: s, height: s, {
  for side in (0, 1) {
    let x0 = if side == 0 { s * 0.2 } else { s * 0.8 }
    let tip = if side == 0 { s * 0.08 } else { s * 0.92 }
    place(polygon(fill: ink, (x0 - s * 0.1, s * 0.3), (tip, s * 0.02), (x0 + s * 0.1, s * 0.24)))
  }
  for fx in (0.28, 0.62) {
    place(dx: s * fx, dy: s * 0.82, ellipse(width: s * 0.14, height: s * 0.12, fill: ink))
  }
  place(dx: s * 0.1, dy: s * 0.14, ellipse(width: s * 0.8, height: s * 0.76, fill: ink))
  centred(s, number(s, value, fill: white, scale: 0.4), dy: s * 0.06)
})

#let coin(s) = box(width: s, height: s, {
  place(dx: s * 0.12, dy: s * 0.12, circle(radius: s * 0.38, fill: ink))
  place(dx: s * 0.22, dy: s * 0.22, circle(radius: s * 0.28, stroke: s * 0.05 + white))
  centred(s, text(s * 0.36, font: mono, weight: "bold", fill: white)[¢])
})

#let chest(s) = box(width: s, height: s, {
  place(dx: s * 0.1, dy: s * 0.2, rect(width: s * 0.8, height: s * 0.26, radius: (top: s * 0.16),
        fill: white, stroke: s * 0.06 + ink))
  place(dx: s * 0.1, dy: s * 0.46, rect(width: s * 0.8, height: s * 0.36, fill: white, stroke: s * 0.06 + ink))
  place(dx: s * 0.4, dy: s * 0.38, rect(width: s * 0.2, height: s * 0.22, fill: ink))
  place(dx: s * 0.47, dy: s * 0.45, rect(width: s * 0.06, height: s * 0.08, fill: white))
})

#let web(s) = box(width: s, height: s, {
  let c = s / 2
  let at(r, a) = (c + r * calc.cos(a), c + r * calc.sin(a))
  let st = s * 0.035 + ink
  for i in range(8) {
    place(line(start: (c, c), end: at(s * 0.48, i * 45deg + 22.5deg), stroke: st))
  }
  for r in (0.14, 0.27, 0.4) {
    place(polygon(stroke: st, ..range(8).map(i => at(s * r, i * 45deg + 22.5deg))))
  }
})

#let spiral(s) = box(width: s, height: s, {
  let c = s / 2
  let steps = 60
  let pts = range(steps + 1).map(i => {
    let t = i / steps
    let a = t * 3.3 * 360deg
    let r = s * 0.46 * t
    (c + r * calc.cos(a), c + r * calc.sin(a))
  })
  place(curve(stroke: (paint: ink, thickness: s * 0.07, cap: "round"),
    curve.move(pts.at(0)), ..pts.slice(1).map(p => curve.line(p))))
})

#let key(s) = box(width: s, height: s, {
  place(dx: s * 0.06, dy: s * 0.3, circle(radius: s * 0.19, stroke: s * 0.08 + ink, fill: white))
  place(line(start: (s * 0.44, s * 0.49), end: (s * 0.94, s * 0.49), stroke: s * 0.09 + ink))
  place(line(start: (s * 0.74, s * 0.49), end: (s * 0.74, s * 0.68), stroke: s * 0.09 + ink))
  place(line(start: (s * 0.88, s * 0.49), end: (s * 0.88, s * 0.64), stroke: s * 0.09 + ink))
})

#let keyhole(s) = box(width: s, height: s, {
  place(dx: s * 0.18, dy: s * 0.18, rect(width: s * 0.64, height: s * 0.64, radius: s * 0.08,
        fill: white, stroke: s * 0.07 + ink))
  place(dx: s * 0.41, dy: s * 0.32, circle(radius: s * 0.09, fill: ink))
  place(polygon(fill: ink, (s * 0.5, s * 0.4), (s * 0.58, s * 0.66), (s * 0.42, s * 0.66)))
})

#let stairs(s) = box(width: s, height: s, place(polygon(
  fill: stone, stroke: (paint: ink, thickness: s * 0.06, join: "round"),
  (s * 0.08, s * 0.92), (s * 0.08, s * 0.66), (s * 0.36, s * 0.66), (s * 0.36, s * 0.4),
  (s * 0.64, s * 0.4), (s * 0.64, s * 0.14), (s * 0.92, s * 0.14), (s * 0.92, s * 0.92),
)))

#let hero(s) = box(width: s, height: s, {
  place(dx: s * 0.06, dy: s * 0.06, circle(radius: s * 0.44, fill: white, stroke: s * 0.07 + ink))
  for fx in (0.34, 0.58) {
    place(dx: s * fx, dy: s * 0.3, circle(radius: s * 0.045, fill: ink))
  }
  place(curve(stroke: (paint: ink, thickness: s * 0.06, cap: "round"),
    curve.move((s * 0.3, s * 0.56)), curve.quad((s * 0.5, s * 0.78), (s * 0.7, s * 0.56))))
})

#let icon(kind, s, value: none) = {
  if kind == "enemy" { enemy(s, value) }
  else if kind == "heart" { heart(s, value) }
  else if kind == "coin" { coin(s) }
  else if kind == "chest" { chest(s) }
  else if kind == "web" { web(s) }
  else if kind == "teleporter" { spiral(s) }
  else if kind == "key" { key(s) }
  else if kind == "lock" { keyhole(s) }
  else if kind == "stairs" { stairs(s) }
  else if kind == "hero" { hero(s) }
}

#let inline(kind, value: none) = box(baseline: 22%, icon(kind, 1.3em, value: value))

// Floor map -----------------------------------------------------------------------

// Stable per-cell choice, so stones don't repeat in obvious stripes.
#let pick(n, x, y) = calc.rem(calc.abs(x * 7 + y * 13 + calc.rem(x * y, 5)), n)

// A wall cell: stone blocks in one of a few masonry patterns.
#let wall-cell(c, x, y) = {
  let g = c * 0.05
  let block(dx, dy, w, h, shade) = place(dx: dx + g, dy: dy + g,
    rect(width: w - 2 * g, height: h - 2 * g, radius: c * 0.12, fill: shade, stroke: none))
  let v = pick(5, x, y)
  let shade = if pick(3, y, x) == 0 { stone-dark } else { stone }
  if v == 0 or v == 1 {
    block(0pt, 0pt, c, c, shade)
  } else if v == 2 {
    block(0pt, 0pt, c, c / 2, stone)
    block(0pt, c / 2, c, c / 2, stone-dark)
  } else if v == 3 {
    block(0pt, 0pt, c / 2, c, stone-dark)
    block(c / 2, 0pt, c / 2, c, stone)
  } else {
    block(0pt, 0pt, c / 2, c / 2, stone)
    block(c / 2, 0pt, c / 2, c / 2, stone-dark)
    block(0pt, c / 2, c, c / 2, stone)
  }
}

// The 13 × 13 floor inside a one-cell stone border.
#let floor-map(fl, c) = {
  let rows = fl.rows.map(r => r.clusters())
  let (w, h) = (rows.at(0).len(), rows.len())
  let objects = (:)
  for o in fl.objects { objects.insert(str(o.x) + "," + str(o.y), o) }
  let (sx, sy) = fl.start
  let (tx, ty) = fl.stairs
  let at(x, y, body) = place(dx: (x + 1) * c, dy: (y + 1) * c, body)
  let s = c * 0.82
  let inset(body) = place(dx: (c - s) / 2, dy: (c - s) / 2, body)

  box(width: (w + 2) * c, height: (h + 2) * c, {
    for y in range(-1, h + 1) {
      for x in range(-1, w + 1) {
        let border = x < 0 or y < 0 or x >= w or y >= h
        if border or rows.at(y).at(x) == "#" {
          at(x, y, wall-cell(c, x, y))
        } else if (x, y) == (sx, sy) {
          at(x, y, inset(icon("hero", s)))
        } else if (x, y) == (tx, ty) {
          at(x, y, inset(icon("stairs", s)))
        } else if str(x) + "," + str(y) in objects {
          let o = objects.at(str(x) + "," + str(y))
          if o.kind == "lock" { at(x, y, wall-cell(c, x, y)) }
          at(x, y, inset(icon(o.kind, s, value: o.value)))
        } else {
          // Empty cells you can take the stairs from get a bigger dot.
          let near = calc.abs(x - tx) <= 1 and calc.abs(y - ty) <= 1
          let r = if near { c * 0.11 } else { c * 0.045 }
          at(x, y, place(dx: c / 2 - r, dy: c / 2 - r, circle(radius: r, fill: if near { ink } else { faint })))
        }
      }
    }
  })
}

// Ledger ---------------------------------------------------------------------------

// Running totals for one page: what you came in with, what you gained and
// lost along the way, and what you leave with.
#let ledger(width) = {
  let gap = 0.35em
  let cw = (width - 3em - 4 * gap) / 4
  let rh = 2.4em
  let cell(body, fill: soft) = box(width: cw, height: rh, radius: 0.5em, fill: fill,
    inset: (x: 0.6em), align(right + horizon, body))
  let head(body) = box(width: cw, align(center, label(9pt, body)))
  let unit(body) = text(9pt * kt, font: mono, weight: "bold", fill: faint, body)
  grid(columns: (3em, cw, cw, cw, cw), column-gutter: gap, row-gutter: gap, align: horizon,
    [], head[Start], head[+], head[−], head[End],
    label(10pt)[HP], cell(unit[HP]), cell(none), cell(none), cell(unit[\/ #h(1.6em) HP]),
    label(10pt)[¢], cell(unit[¢]), cell(none), cell(none), cell(unit[¢]),
  )
}

// Cover ----------------------------------------------------------------------------

#page(footer: none, align(center + horizon, {
  stop("Cover", "◆", mark: "major")
  let c = 1.1cm * k
  box(width: 7 * c, height: 5 * c, {
    for y in range(5) {
      for x in range(7) {
        let edge = x == 0 or y == 0 or x == 6 or y == 4
        place(dx: x * c, dy: y * c, if edge { wall-cell(c, x, y) })
      }
    }
    place(dx: 1.1 * c, dy: 2 * c, icon("hero", c * 0.8))
    place(dx: 2.6 * c, dy: 1.1 * c, icon("enemy", c * 0.8, value: 3))
    place(dx: 3.2 * c, dy: 2.6 * c, icon("coin", c * 0.8))
    place(dx: 4.1 * c, dy: 1.6 * c, icon("heart", c * 0.8, value: 2))
    place(dx: 5.1 * c, dy: 3.1 * c, icon("stairs", c * 0.8))
  })
  v(1.2cm * k)
  text(46pt * kt, font: mono, weight: "bold", tracking: 0.08em)[DUNGEON]
  v(0.3cm * k)
  text(11pt * kt, fill: faint)[#data.floors.len() floors · seed #data.seed]
}))

// Rules ----------------------------------------------------------------------------

#let section(body) = {
  v(0.5em)
  text(11pt * kt, font: mono, weight: "bold", body)
  v(0.1em)
}

#pagebreak()
#stop("How to play", "?", mark: "major")
#title(22pt)[How to play]
#v(0.3cm * k)
#set par(justify: true, spacing: 0.75em)
#columns(if pocket { 1 } else { 2 }, gutter: 0.8cm)[
  #set text(9.5pt * kt)

  #section[The goal]
  Fight, loot and stumble your way down #data.floors.len() floors to the treasure at
  the bottom. Each page is one floor: start on #inline("hero") and find the stairs
  #inline("stairs"). You need a pencil and one six-sided die.

  #section[Moving]
  Roll the die: that's how many squares you move this turn.
  - *Odd (1, 3, 5):* move diagonally.
  - *Even (2, 4, 6):* move straight up, down, left or right.
  Pick a direction and keep going straight. If a wall gets in the way, turn to
  another direction of the same kind and carry on until you've moved the full
  roll. Draw your path, and cross the square where you stop.

  If any direction lets you go the whole roll without hitting a wall, you have to
  pick one of those. Don't double back the way you just came unless there's no
  other way.

  #section[Taking the stairs]
  Leave the floor when you stop on the stairs or on any square touching them
  (the big dots), or when your path crosses them. You don't have to: stay and
  explore for loot and hearts as long as you like.

  #section[HP and coins]
  You start with #data.start_hp HP (that's also your maximum) and 0¢. Copy them into
  *Start* on each page. As you play the floor, write gains in *+* and losses in
  *−*. Don't total anything until you take the stairs: a big − in the middle of a
  floor won't kill you if you find hearts before you leave.

  Leaving: *End* = Start + gains − losses. HP can't go above your maximum and
  coins can't go below 0. End becomes the next page's Start.

  #section[Falling]
  If you leave a floor with 0 HP or less, you've died. Tally it on the stats page,
  then start the next floor with full HP and 0¢.

  #if not pocket { colbreak() }
  #section[What you'll find]
  Everything you move onto counts, once; cross it off when it's used. Only the
  stairs and a teleporter you've used before can be passed by.

  #set par(justify: false)
  #grid(columns: (auto, 1fr), column-gutter: 0.7em, row-gutter: 0.75em, align: (center + horizon, left + horizon),
    inline("coin"), [*Coin:* +1¢.],
    inline("chest"), [*Chest:* roll, and gain that many ¢.],
    inline("enemy", value: 3), [*Enemy:* lose its number in HP.],
    inline("enemy"), [*Mystery enemy:* roll to see how much HP you lose.],
    inline("heart", value: 2), [*Heart:* gain its number in HP.],
    inline("heart"), [*Mystery heart:* roll to see how much HP you gain.],
    inline("web"), [*Spiderweb:* stops you dead. Roll, and lose that many ¢.],
    inline("key"), [*Key:* opens this floor's locked door.],
    inline("lock"), [*Locked door:* a wall until you have the key.],
    inline("teleporter"), [*Teleporter:* jump to the other one and carry on in the same
      direction with the rest of your move.],
  )

  #section[Shops]
  Every few floors there's a shop. Buy what you can afford: tick it and add the
  price to the shop's − ¢. Tick *Used* when you use an item up.
]

// Hero -----------------------------------------------------------------------------

#pagebreak()
#stop("Your hero", "☺", mark: "major")
#set par(justify: false)
#align(center, title(20pt)[Your hero])
#v(0.5cm * k)
#layout(size => {
  let w = size.width
  box(width: w, height: size.height - 4cm * k, radius: 0.6cm * k, stroke: (paint: faint, thickness: 1pt, dash: "dashed"),
    align(center + horizon, text(10pt * kt, fill: faint)[draw your hero here]))
  v(0.8cm * k)
  grid(columns: (auto, 1fr), column-gutter: 0.6em, align: bottom,
    label(11pt)[Name], box(width: 100%, stroke: (bottom: 0.8pt + ink), h(1em)))
})

// Floors and shops -----------------------------------------------------------------------

#let group(n) = {
  let lo = calc.floor((n - 1) / 10) * 10 + 1
  let hi = calc.min(lo + 9, data.floors.len())
  "Floors " + str(lo) + "–" + str(hi)
}

#let shop-page(after) = {
  pagebreak()
  stop("Shop", "¢", group: group(after))
  layout(size => {
    let w = size.width
    // A sign hanging from two chains.
    align(center, box(width: w * 0.6, {
      for fx in (0.18, 0.82) {
        place(dx: w * 0.6 * fx, line(start: (0pt, 0pt), end: (0pt, 0.7cm * k), stroke: (paint: faint, thickness: 1.2pt, dash: "dotted")))
      }
      v(0.7cm * k)
      box(width: w * 0.6, height: 1.6cm * k, radius: 0.3cm * k, fill: ink,
        align(center + horizon, text(24pt * kt, font: mono, weight: "bold", fill: white, tracking: 0.1em)[SHOP]))
    }))
    v(1cm * k)
    let tick(size) = box(width: size, height: size, radius: size * 0.15, stroke: 1pt + ink)
    for item in data.items {
      block(width: w, inset: (y: 0.4em), grid(columns: (3.2em, 1fr, auto), column-gutter: 0.8em, align: (center + top, left + top, right + top),
        stack(spacing: 0.35em, tick(1.6em), label(9pt)[#item.price¢]),
        [#label(12pt)[#item.name] \ #text(9pt * kt)[#item.text#if item.once [ Use once.]]],
        if item.once { box(baseline: 30%, tick(1.1em)); h(0.3em); label(8pt)[Used] },
      ))
      v(0.7cm * k)
    }
    v(1fr)
    ledger(w)
    v(0.4cm * k)
  })
}

#for fl in data.floors {
  let n = fl.number
  pagebreak()
  stop("Floor " + str(n), str(n), group: group(n), mark: if calc.rem(n, 10) == 1 { "major" } else { "minor" })
  layout(size => {
    let w = size.width
    title(20pt)[Floor #n]
    v(0.3cm * k)
    let ledger-h = measure(ledger(w)).height
    let room = size.height - ledger-h - (3.2em).to-absolute()
    let c = calc.min(w / 15, room / 15)
    align(center, floor-map(fl, c))
    v(1fr)
    ledger(w)
  })
  if n in data.shops { shop-page(n) }
}

// Treasure ---------------------------------------------------------------------------

// A cut gem: a girdle of `sides` points, a table on the crown and facet
// lines down to the point of the pavilion.
#let gem(g, width) = {
  let n = g.sides
  let hgt = width * 0.82
  let gy = hgt * g.crown
  let girdle = range(n + 1).map(i => (width * i / n, gy))
  let table-l = width * 0.28
  let table-r = width * 0.72
  let tip = (width / 2, hgt)
  let outline = ((table-l, 0pt), (table-r, 0pt), (width, gy), tip, (0pt, gy))
  box(width: width, height: hgt, {
    place(polygon(fill: soft, stroke: (paint: ink, thickness: 1.6pt, join: "round"), ..outline))
    let st = 0.8pt + ink
    place(line(start: (0pt, gy), end: (width, gy), stroke: st))
    for (x, y) in girdle.slice(1, n) {
      place(line(start: (x, y), end: tip, stroke: st))
      let tx = table-l + (table-r - table-l) * (x / width)
      place(line(start: (x, y), end: (tx, 0pt), stroke: st))
    }
    place(polygon(fill: white.transparentize(30%), stroke: none,
      (table-l + width * 0.03, gy * 0.15), (width * 0.42, gy * 0.15), (width * 0.3, gy * 0.85), (width * 0.12, gy * 0.85)))
  })
}

#pagebreak()
#stop("Treasure", "◇", mark: "major")
#align(center + horizon, {
  label(11pt, fill: faint)[BELOW THE LAST FLOOR LIES]
  v(1cm * k)
  gem(data.gem, 7cm * k)
  v(1cm * k)
  title(18pt, data.gem.name)
  v(0.6cm * k)
  text(10pt * kt, fill: faint)[It's yours. Write down the day you found it on the next page.]
})

// Stats ------------------------------------------------------------------------------

#pagebreak()
#stop("Stats", "♥", mark: "major")
#align(center, title(20pt)[Stats])
#v(0.8cm * k)
#layout(size => {
  let w = size.width
  let s = w * 0.3
  let tombstone = box(width: s, height: s * 1.25, {
    place(rect(width: s, height: s * 1.25, radius: (top: s / 2), fill: soft, stroke: 1.4pt + ink))
    place(dy: s * 0.28, box(width: s, align(center, label(12pt)[R.I.P.])))
    place(dx: s * 0.15, dy: s * 0.5, box(width: s * 0.7, height: s * 0.6, stroke: (paint: faint, dash: "dashed"), radius: 0.2em))
  })
  let disc = box(width: s * 0.7, height: s * 0.7, circle(radius: s * 0.35, fill: soft, stroke: 1.4pt + ink))
  let big-heart = box(width: s * 0.7, height: s * 0.7, heart-shape(s * 0.7, fill: soft, thickness: 1.4pt))
  align(center, grid(columns: 3, column-gutter: w * 0.06, align: bottom + center, row-gutter: 0.6em,
    tombstone, disc, big-heart,
    label(10pt)[Deaths], label(10pt)[Final ¢], label(10pt)[Final HP],
  ))
  v(1.4cm * k)
  let line-field(name) = {
    grid(columns: (auto, 1fr), column-gutter: 0.8em, align: bottom,
      label(10pt)[#name], box(width: 100%, stroke: (bottom: 0.8pt + ink), h(1em)))
    v(1cm * k)
  }
  line-field[Quest began]
  line-field[Quest ended]
  line-field[This notebook belongs to]
})
