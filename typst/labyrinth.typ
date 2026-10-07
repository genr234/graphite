#import "lib/art.typ": corridor, drawing, ink, pale, light, mid, dark

// Notebook data comes from prolog/graphite.pl as a JSON string input.
#let data = json(bytes(sys.inputs.data))
#let paper = sys.inputs.at("paper", default: "a4")
#let faint = luma(150)
#let panel = luma(234)
#let mono = "DejaVu Sans Mono"

// Pocket (A6) pages get imposed into a booklet by impose.typ. Spacing scales
// by `k` and text by `kt`, as in golf.typ.
#let pocket = paper == "a6"
#let k = if pocket { 0.6 } else { 1 }
#let kt = if pocket { 0.72 } else { 1 }

#set page(
  paper: paper,
  fill: white,
  margin: if pocket { (x: 6mm, top: 6mm, bottom: 8mm) } else { (x: 2cm, top: 1.6cm, bottom: 1.6cm) },
  footer: context {
    set text(7pt * kt, fill: faint)
    [LABYRINTH · seed #data.seed]
  },
)
#set text(size: 10pt * kt, fill: ink)

#let title(size, body) = text(size * kt, font: mono, weight: "bold", body)
#let label(size, body, fill: ink) = text(size * kt, font: mono, weight: "bold", fill: fill, body)

// Preview outline for the app's page rail (web/ui/scroller.js).
#let stop(label, short, group: none, mark: "minor") = context [
  #metadata((page: here().page(), label: label, short: short, group: group, mark: mark)) <stop>
]

// Small pieces ----------------------------------------------------------------

#let heart(size, fill: white) = box(width: size, height: size, baseline: 15%, place(curve(
  fill: fill, stroke: (paint: ink, thickness: size * 0.08, join: "round"),
  curve.move((0.5 * size, 0.9 * size)),
  curve.cubic((0.1 * size, 0.62 * size), (-0.04 * size, 0.28 * size), (0.22 * size, 0.14 * size)),
  curve.cubic((0.38 * size, 0.06 * size), (0.5 * size, 0.18 * size), (0.5 * size, 0.28 * size)),
  curve.cubic((0.5 * size, 0.18 * size), (0.62 * size, 0.06 * size), (0.78 * size, 0.14 * size)),
  curve.cubic((1.04 * size, 0.28 * size), (0.9 * size, 0.62 * size), (0.5 * size, 0.9 * size)),
  curve.close(),
)))

#let pips = (
  "1": ((0.5, 0.5),),
  "2": ((0.27, 0.27), (0.73, 0.73)),
  "3": ((0.25, 0.25), (0.5, 0.5), (0.75, 0.75)),
  "4": ((0.27, 0.27), (0.73, 0.27), (0.27, 0.73), (0.73, 0.73)),
  "5": ((0.25, 0.25), (0.75, 0.25), (0.5, 0.5), (0.25, 0.75), (0.75, 0.75)),
  "6": ((0.28, 0.22), (0.72, 0.22), (0.28, 0.5), (0.72, 0.5), (0.28, 0.78), (0.72, 0.78)),
)

#let die(n, size) = box(width: size, height: size,
  rect(width: size, height: size, radius: size * 0.18, fill: white, stroke: size * 0.04 + mid, inset: 0pt, {
    for (x, y) in pips.at(str(n)) {
      place(dx: x * size - size * 0.09, dy: y * size - size * 0.09, circle(radius: size * 0.09, fill: ink))
    }
  }))

#let tick-box(size, round: false) = box(baseline: 15%,
  if round { circle(radius: size / 2, stroke: 0.9pt + ink, fill: white) }
  else { rect(width: size, height: size, radius: size * 0.12, stroke: 0.9pt + ink, fill: white) })

#let key-icon(size) = box(width: size * 1.6, height: size, baseline: 10%, {
  place(dy: size * 0.2, circle(radius: size * 0.3, stroke: size * 0.12 + ink, fill: white))
  place(line(start: (size * 0.58, size * 0.5), end: (size * 1.55, size * 0.5), stroke: size * 0.14 + ink))
  place(line(start: (size * 1.2, size * 0.5), end: (size * 1.2, size * 0.8), stroke: size * 0.14 + ink))
  place(line(start: (size * 1.45, size * 0.5), end: (size * 1.45, size * 0.75), stroke: size * 0.14 + ink))
})

// Compass: which way the picture faces. The needle's N end shows where north
// is from the viewer: up when facing north, left when facing east, and so on.
#let compass-angle = (n: 0deg, e: -90deg, s: 180deg, w: 90deg)
#let compass(facing, size) = box(width: size, height: size,
  circle(radius: size / 2, stroke: 1.1pt + ink, fill: white, {
    if facing == "?" {
      place(center + horizon, title(size * 0.55 / kt / 1pt * 1pt, "?"))
    } else {
      place(center + horizon, rotate(compass-angle.at(facing), reflow: false, box(width: size * 0.36, height: size * 0.8, {
        let (w, h) = (size * 0.36, size * 0.8)
        place(polygon(fill: ink, stroke: 0.6pt + ink, (w / 2, 0pt), (w, h / 2), (0pt, h / 2)))
        place(polygon(fill: light, stroke: 0.6pt + ink, (0pt, h / 2), (w, h / 2), (w / 2, h)))
        place(dx: 0pt, dy: h * 0.18, box(width: w, align(center, text(size * 0.2, font: mono, weight: "bold", fill: white)[N])))
      })))
    }
  }))

#let now-sign(size) = box(width: size, height: size, {
  place(polygon(fill: ink, stroke: (paint: ink, thickness: size * 0.08, join: "round"),
    (size / 2, size * 0.04), (size * 0.98, size * 0.86), (size * 0.02, size * 0.86)))
  place(dy: size * 0.22, box(width: size, align(center, text(size * 0.5, font: mono, weight: "bold", fill: white)[!])))
})

#let tally(name, size) = box(height: size, baseline: 30%, {
  set text(size * 0.5, font: mono, weight: "bold")
  grid(columns: (size * 1.1, size * 3.4), column-gutter: size * 0.15, align: (right + horizon, horizon),
    box(height: size, align(right + horizon, name)),
    box(width: size * 3.4, height: size, radius: size / 2, stroke: 0.9pt + mid, fill: white, inset: 0pt,
    grid(columns: (1fr, 1fr), align: center + horizon,
      box(height: size, align(center + horizon, text(fill: faint)[−])),
      box(height: size, stroke: (left: 0.9pt + mid), align(center + horizon, text(fill: faint)[+])))))
})

#let room-badge(n, size) = box(width: size, height: size,
  circle(radius: size / 2, stroke: 1.4pt + ink, fill: white,
    align(center + horizon, text(size * 0.42, font: mono, weight: "bold", str(n)))))

// Encounter body ----------------------------------------------------------------

#let die-table(cells, header, width) = {
  let gap = width * 0.015
  let d = (width - gap * 7) / 6
  block(width: width, fill: panel, radius: d * 0.22, inset: gap, {
    if header != none { pad(left: gap, bottom: gap * 1.6, top: gap * 0.6, header) }
    grid(columns: (d,) * 6, column-gutter: gap, row-gutter: gap,
      ..range(1, 7).map(n => die(n, d)),
      ..cells.map(c => {
        let span = c.to - c.from + 1
        let cw = d * span + gap * (span - 1)
        // Monospace glyphs are 0.6em wide: shrink long labels to fit the cell.
        let size = calc.min(d * 0.19, cw / (c.label.clusters().len() * 0.62 + 0.8))
        grid.cell(colspan: span, box(width: 100%, height: d * 0.4, radius: d * 0.1, fill: dark,
          align(center + horizon, text(size, font: mono, weight: "bold", fill: white, c.label))))
      }))
  })
}

#let option-list(items, round, width) = {
  let h = 1.3em
  stack(spacing: 0.5em * k, ..items.map(item => block(width: width, fill: panel, radius: 0.4em,
    inset: (x: 0.7em, y: 0.55em), grid(columns: (auto, 1fr), column-gutter: 0.6em, align: horizon,
      tick-box(0.95em, round: round), text(weight: "bold", item)))))
}

// Room pages set their text size from the page width, so the em sizes below
// keep the same proportions on A4, Letter and pocket pages.
#let em-label(body, size: 0.8em, fill: ink) = text(size, font: mono, weight: "bold", fill: fill, body)

#let body(room, width) = {
  if room.kind == "battle" {
    let header = {
      em-label[#room.enemy]
      h(0.6em)
      for _ in range(room.hearts) { heart(1.15em); h(0.2em) }
    }
    die-table(room.table, header, width)
  } else if room.kind == "roll" {
    let header = if room.at("game", default: none) != none {
      em-label[Score:]
      h(0.4em)
      box(width: 4em, height: 1em, stroke: (bottom: 0.8pt + ink))
    } else { em-label[Roll for result:] }
    die-table(room.table, header, width)
  } else if room.kind == "choice" {
    option-list(room.options, true, width)
    v(0.6em)
    die-table(room.table, em-label[Roll for result:], width)
  } else if room.kind in ("shop", "armory") {
    option-list(room.options, false, width)
  }
}

#let footer(room, width) = {
  let s = width * 0.125
  let tick(body) = { tick-box(0.95em); h(0.35em); em-label(body) }
  grid(columns: (s, s * 0.9, 1fr, auto, s), column-gutter: 0.5em, align: horizon,
    compass(room.facing, s),
    if room.now { align(center, stack(spacing: 0.2em, now-sign(s * 0.55), em-label(size: 0.65em)[NOW])) },
    align(center, stack(spacing: 0.5em, tally("HP", s * 0.36), tally("¢", s * 0.36))),
    stack(spacing: 0.45em,
      tick[DONE],
      if room.loot != none {
        box(width: 2.2em, height: 1.3em, stroke: 0.9pt + mid, radius: 0.3em, baseline: 25%,
            align(center + horizon, em-label(room.loot)))
        h(0.35em)
        em-label[LOOT]
      } else if room.at("key", default: none) != none {
        key-icon(0.75em)
        h(0.3em)
        em-label[KEY #room.key]
      }),
    room-badge(room.number, s),
  )
}

// Cover and rules ---------------------------------------------------------------

#page(footer: none, align(center + horizon, {
  stop("Cover", "◆", mark: "major")
  corridor(9cm * k, 7.5cm * k, ("front", "left", "right"), _ => none,
           art: s => drawing("bullgrim", s), size: 0.55)
  v(1cm * k)
  text(44pt * kt, font: mono, weight: "bold", tracking: 0.08em)[LABYRINTH]
  v(0.3cm * k)
  text(11pt * kt, fill: faint)[#data.rooms.len() rooms · #data.levels levels · seed #data.seed]
}))

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
  You're lost in a two-level maze. Each page is one room, numbered in the round
  badge at its foot. Find the lair of the BULLGRIM and beat it to escape.
  You need a pencil and one six-sided die.

  #section[Getting around]
  Start in room 1. The picture shows the room as you stand in it; numbered
  arrows are its doorways: ahead, left, right and behind. Ladders lead up or
  down a level. To move, turn to the room with that number.

  You can't walk past a room's encounter until it's done. Until then you may
  only leave the way you came in. Some encounters are marked #box(now-sign(1em)) NOW:
  deal with them before anything else.

  Once you've visited a room you can jump straight back to it at any time.

  #section[Mapping]
  The compass shows which way the picture faces. Use it to write each room's
  number in the right square of the Master Map, and to draw its walls. A room
  with a #box(baseline: 20%, circle(radius: 0.5em, stroke: 0.8pt + ink, align(center + horizon, text(0.8em, font: mono, weight: "bold")[?]))) has a broken compass: work out its facing from the way you came in.

  #section[Locked doors]
  A doorway with a key letter is locked. Beat the guardian that carries the key
  and tick the key on the Master Map. A key works on every door with its letter.

  #section[HP and coins]
  You start with 10 HP and 0¢. Every time either changes, cross out the last
  number on the Player Stats page and write the new one. Coins never go below 0.
  Use the HP and ¢ tallies at the foot of each page while you play a room.

  #if not pocket { colbreak() }
  #section[Battles]
  Roll the die and read the face under the enemy's hearts:
  - *HIT:* cross out as many hearts as your weapon's DMG.
  - *MISS:* nothing happens.
  - *−HP* or *±¢:* change your HP or coins.
  Keep rolling until the enemy's hearts are all crossed out, then tick DONE and
  add its LOOT to your coins (roll if it says d6). Crossed-out hearts stay
  crossed out, even if you leave.

  #section[Weapons]
  You start with a knife (1 DMG). Buy better ones from the smiths and tick them on
  the stats page; always use your best. The axe lets you re-roll one die per enemy.
  The shield blocks the first attack of each battle.

  #section[Other rooms]
  - *Roll for result:* roll once and apply the face. ROLL AGAIN means just that.
  - *Round boxes:* choose one option.
  - *Square boxes:* take as many as you like and can pay for, now or later.

  #section[Dying]
  At 0 HP you fall. Add a mark to the death tally, lose 5¢, set your HP back to 10
  and carry on from any room you've already visited.

  #section[Score]
  When the BULLGRIM falls, your score is your coins, plus 10 if every room is
  DONE, minus 3 for each death.
]

// Rooms ----------------------------------------------------------------------

#set par(justify: false)
#let group(n) = {
  let lo = calc.floor((n - 1) / 10) * 10 + 1
  "Rooms " + str(lo) + "–" + str(lo + 9)
}

#for room in data.rooms {
  pagebreak()
  stop("Room " + str(room.number), str(room.number), group: group(room.number),
       mark: if calc.rem(room.number, 10) == 1 { "major" } else { "minor" })
  layout(size => {
    // A column with the pocket page's proportions, centred on bigger paper.
    let w = calc.min(size.width, size.height * 0.68)
    set text(w * 0.027)
    let words = {
      set text(weight: "bold")
      set par(leading: 0.5em, justify: false)
      for line in room.text { line; linebreak() }
    }
    // The picture takes whatever height the words, table and footer leave.
    // `measure` doesn't see the set rule above, so give it the size again.
    let sized(it) = block(width: w, { set text(w * 0.027); it })
    let rest = measure(sized({ words; v(0.5em); body(room, w) })).height
    let foot = measure(sized(footer(room, w))).height
    let vh = calc.max(w * 0.45, calc.min(w * 0.95, size.height - rest - foot - w * 0.027 * 2.4))
    let num = w * 0.042
    let label(side) = text(num, font: mono, weight: "bold", fill: white,
                           str(room.exits.find(e => e.side == side).to))
    let lock(side) = {
      let e = room.exits.find(e => e.side == side)
      if e.lock != none {
        box(fill: white, stroke: 0.8pt + ink, radius: 0.25em, inset: (x: 0.3em, y: 0.2em),
            { key-icon(num * 0.55); h(0.2em); text(num * 0.7, font: mono, weight: "bold", e.lock) })
      }
    }
    align(center, box(width: w, height: size.height, {
      corridor(w, vh, room.exits.map(e => e.side), label, lock: lock,
               art: s => drawing(room.art, s, m: room.at("monster", default: none)),
               size: if room.kind == "start" { 0.5 } else { 0.56 })
      v(0.6em)
      words
      v(0.5em)
      set align(left)
      body(room, w)
      place(bottom, footer(room, w))
    }))
  })
}

// Trackers ---------------------------------------------------------------------

// A log grid: write the current value in the next cell each time it changes.
#let log-grid(first, cols, rows, width, note: none) = {
  let c = width / cols
  box(width: width, height: c * rows, radius: c * 0.25, stroke: 1pt + mid, clip: true, {
    for x in range(1, cols) { place(line(start: (x * c, 0pt), end: (x * c, c * rows), stroke: 0.6pt + light)) }
    for y in range(1, rows) { place(line(start: (0pt, y * c), end: (width, y * c), stroke: 0.6pt + light)) }
    place(rect(width: c, height: c, fill: light, stroke: none))
    place(box(width: c, height: c, align(center + horizon, label(9pt, first))))
    if note != none {
      let x = (cols - 5) * c
      place(dx: x, dy: (rows - 1) * c, rect(width: width - x, height: c, fill: white, stroke: (left: 0.6pt + light, top: 0.6pt + light)))
      place(dx: x + 0.3em, dy: (rows - 1) * c + 0.25em, text(6pt * kt, font: mono, fill: faint, note))
    }
  })
}

#pagebreak()
#stop("Player Stats", "♥", group: "Trackers", mark: "major")
#layout(size => {
  let w = size.width
  align(center, title(18pt)[Player Stats])
  v(0.4em * k)
  label(9pt)[HP]
  v(0.15em)
  log-grid("10", 11, 5, w, note: [DEATH TALLY])
  v(0.6em * k)
  label(9pt)[¢]
  v(0.15em)
  log-grid("0", 11, 5, w)
  v(0.8em * k)
  let s = (w - 4 * 0.6em) / 5
  let item(name, art, note, ticked) = box(width: s, {
    box(width: s, height: s * 0.85, radius: s * 0.12, stroke: 1pt + mid, {
      place(center + horizon, art)
      place(bottom + right, dx: -s * 0.05, dy: -s * 0.05, {
        box(width: s * 0.14, height: s * 0.14, {
          tick-box(s * 0.14)
          if ticked {
            place(line(start: (0pt, 0pt), end: (s * 0.14, s * 0.14), stroke: 1pt + ink))
            place(line(start: (s * 0.14, 0pt), end: (0pt, s * 0.14), stroke: 1pt + ink))
          }
        })
      })
    })
    v(0.2em)
    align(center, { label(8pt, name); linebreak(); text(6.5pt * kt, font: mono, fill: dark, note) })
  })
  let blade(len, head) = box(width: s * 0.6, height: s * 0.6, rotate(-45deg, {
    let l = s * 0.6 * len
    place(center + horizon, stack(dir: ttb,
      if head == "mace" { circle(radius: s * 0.08, fill: mid, stroke: 1pt + ink) }
      else if head == "axe" { polygon(fill: light, stroke: 1pt + ink, (0pt, 0pt), (s * 0.22, s * 0.05), (s * 0.22, s * 0.2), (0pt, s * 0.15)) }
      else { polygon(fill: white, stroke: 1pt + ink, (s * 0.04, 0pt), (s * 0.08, l * 0.12), (s * 0.08, l * 0.6), (0pt, l * 0.6), (0pt, l * 0.12)) },
      rect(width: s * 0.04, height: l * 0.4, fill: ink)))
  }))
  let shield = polygon(fill: light, stroke: 1.2pt + ink, (0pt, 0pt), (s * 0.4, 0pt), (s * 0.4, s * 0.28), (s * 0.2, s * 0.5), (0pt, s * 0.28))
  let names = data.weapons.map(w => w.name)
  grid(columns: 5, column-gutter: 0.6em,
    ..data.weapons.map(wp => item(upper(wp.name),
      blade(if wp.name == "Knife" { 0.6 } else { 1 }, lower(wp.name)),
      [#wp.damage DMG#if wp.name == "Axe" [ \ 1 re-roll \ per enemy]],
      wp.name == "Knife")),
    item("SHIELD", shield, [Blocks the \ first attack \ each battle], false))
})

#pagebreak()
#stop("Master Map", "#", group: "Trackers")
#layout(size => {
  let w = size.width
  align(center, title(18pt)[Master Map])
  align(center, text(7.5pt * kt, font: mono, fill: faint)[WRITE IN ROOM NUMBERS AND DRAW WALLS AS YOU GO])
  v(0.6em * k)
  let (cols, rows) = (data.width, data.height)
  let gh = calc.min(w * 0.62, (size.height - 6cm * k) / data.levels * 0.82)
  let gw = calc.min(w, gh * 1.45)
  // A grid seen at a slant: the top edge is narrower than the bottom.
  let level-grid(level) = {
    let inset = gw * 0.07
    let x-at(fx, fy) = inset * (1 - fy) + fx * (gw - 2 * inset * (1 - fy))
    let y-at(fy) = fy * gh
    let pt(fx, fy) = (x-at(fx, fy), y-at(fy))
    box(width: gw, height: gh, {
      place(polygon(fill: white, stroke: 1pt + mid, pt(0, 0), pt(1, 0), pt(1, 1), pt(0, 1)))
      for i in range(1, cols) { place(line(start: pt(i / cols, 0), end: pt(i / cols, 1), stroke: 0.5pt + light)) }
      for j in range(1, rows) { place(line(start: pt(0, j / rows), end: pt(1, j / rows), stroke: 0.5pt + light)) }
      // Posts where walls meet, to draw walls between.
      for i in range(1, cols) {
        for j in range(1, rows) {
          let (x, y) = pt(i / cols, j / rows)
          place(dx: x - 1.5pt, dy: y - 1.5pt, circle(radius: 1.5pt, fill: dark))
        }
      }
      if level == 1 {
        let (sx, sy) = data.start
        let (x, y) = pt((sx + 0.5) / cols, (sy + 0.5) / rows)
        place(dx: x - 1em, dy: y - 0.6em, box(width: 2em, align(center, label(10pt)[1])))
        let (bx, by) = pt((sx + 0.5) / cols, 1)
        place(dx: bx - 0.4em, dy: by + 0.2em, polygon(fill: ink, (0.4em, 0pt), (0.8em, 0.55em), (0pt, 0.55em)))
      }
    })
  }
  for level in range(data.levels, 0, step: -1) {
    align(center, level-grid(level))
    v(0.4em * k)
    align(center, text(8pt * kt, font: mono, weight: "bold", fill: dark, tracking: 0.2em)[LEVEL #level])
    v(0.6em * k)
  }
  v(1fr)
  align(center, grid(columns: 4, column-gutter: 1.2em, align: horizon,
    compass("n", 1cm * k),
    { key-icon(1em); h(0.2em); label(9pt)[A]; h(0.3em); tick-box(0.9em) },
    { key-icon(1em); h(0.2em); label(9pt)[B]; h(0.3em); tick-box(0.9em) },
    { tick-box(0.9em); h(0.3em); label(9pt)[BULLGRIM BEATEN] },
  ))
})
