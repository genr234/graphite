// LABYRINTH artwork, drawn with plain shapes so it prints crisp in greyscale:
// the corridor viewport, and one figure per encounter `art` key.
//
// Figures are drawn in a unit square: coordinates are fractions of the size
// `s`, x to the right and y downwards, with the floor line at y = 1.

#import "monster.typ": monster

#let ink = luma(35)
#let pale = luma(250)
#let light = luma(228)
#let mid = luma(185)
#let dark = luma(110)

// Primitives ------------------------------------------------------------------

#let pen(s) = (paint: ink, thickness: 0.018 * s, join: "round", cap: "round")

#let at(s, x, y, body) = place(dx: x * s, dy: y * s, body)

#let disc(s, x, y, r, fill: pale) = at(s, x - r, y - r,
  circle(radius: r * s, fill: fill, stroke: pen(s)))

#let oval(s, x, y, rx, ry, fill: pale, stroke: auto) = at(s, x - rx, y - ry,
  ellipse(width: 2 * rx * s, height: 2 * ry * s, fill: fill,
          stroke: if stroke == auto { pen(s) } else { stroke }))

#let slab(s, x, y, w, h, fill: pale, r: 0.03) = at(s, x, y,
  rect(width: w * s, height: h * s, radius: r * s, fill: fill, stroke: pen(s)))

#let poly(s, fill: pale, ..pts) = place(polygon(fill: fill, stroke: pen(s),
  ..pts.pos().map(((x, y)) => (x * s, y * s))))

#let seg(s, x1, y1, x2, y2, w: 1) = place(line(start: (x1 * s, y1 * s), end: (x2 * s, y2 * s),
  stroke: (paint: ink, thickness: 0.018 * s * w, cap: "round")))

#let shadow(s, x: 0.5, w: 0.36) = oval(s, x, 0.97, w, 0.05, fill: luma(200), stroke: none)

// A pair of eyes; angry ones get slanted brows.
#let eyes(s, x, y, gap: 0.09, r: 0.035, angry: true, glow: false) = {
  for dx in (-gap, gap) {
    disc(s, x + dx, y, r, fill: if glow { white } else { white })
    disc(s, x + dx + 0.004, y + 0.006, r * 0.45, fill: ink)
  }
  if angry {
    seg(s, x - gap - r, y - r * 1.6, x - gap * 0.3, y - r * 0.6)
    seg(s, x + gap + r, y - r * 1.6, x + gap * 0.3, y - r * 0.6)
  }
}

#let grin(s, x, y, w: 0.1) = {
  poly(s, fill: ink, (x - w, y), (x + w, y), (x, y + w * 0.6))
}

#let figure-box(s, body) = box(width: s, height: s, body)

// Figures ---------------------------------------------------------------------

// Two-legged creatures share one body plan.
#let biped(s, size: 1, tone: pale, horns: false, ears: false, hood: false,
           blade: false, club: false, ribs: false, wings: false, hat: false, belly: false) = {
  let k = size
  let cx = 0.5
  let top = 1 - 0.9 * k
  let head-r = 0.13 * k
  let hy = top + head-r
  let body-top = hy + head-r * 0.8
  let body-h = 0.36 * k
  let hip = body-top + body-h
  shadow(s, w: 0.22 * k + 0.08)
  if wings {
    poly(s, fill: mid, (cx - 0.08, body-top + 0.05), (cx - 0.42 * k, top), (cx - 0.36 * k, body-top + 0.2), (cx - 0.08, body-top + 0.18))
    poly(s, fill: mid, (cx + 0.08, body-top + 0.05), (cx + 0.42 * k, top), (cx + 0.36 * k, body-top + 0.2), (cx + 0.08, body-top + 0.18))
  }
  // Legs.
  for side in (-1, 1) {
    seg(s, cx + side * 0.06 * k, hip - 0.02, cx + side * 0.1 * k, 0.96, w: 3.2 * k)
    seg(s, cx + side * 0.06 * k, hip - 0.02, cx + side * 0.1 * k, 0.96, w: 1.6 * k)
  }
  // Arms.
  for side in (-1, 1) {
    seg(s, cx + side * 0.12 * k, body-top + 0.05, cx + side * 0.25 * k, hip - 0.02, w: 3 * k)
  }
  // Body.
  if hood {
    poly(s, fill: tone, (cx, top - 0.03), (cx - 0.22 * k, 0.96), (cx + 0.22 * k, 0.96))
  } else {
    slab(s, cx - 0.14 * k, body-top, 0.28 * k, body-h, fill: tone, r: 0.06 * k)
  }
  if belly { oval(s, cx, body-top + body-h * 0.6, 0.09 * k, 0.1 * k, fill: light) }
  if ribs {
    for i in range(3) {
      seg(s, cx - 0.08 * k, body-top + (0.08 + i * 0.08) * k, cx + 0.08 * k, body-top + (0.08 + i * 0.08) * k)
    }
  }
  // Head.
  if ears {
    poly(s, fill: tone, (cx - 0.08 * k, hy - 0.02), (cx - 0.24 * k, hy - 0.1 * k), (cx - 0.1 * k, hy + 0.05 * k))
    poly(s, fill: tone, (cx + 0.08 * k, hy - 0.02), (cx + 0.24 * k, hy - 0.1 * k), (cx + 0.1 * k, hy + 0.05 * k))
  }
  if horns {
    poly(s, fill: light, (cx - 0.07 * k, hy - 0.08 * k), (cx - 0.22 * k, hy - 0.22 * k), (cx - 0.13 * k, hy - 0.02 * k))
    poly(s, fill: light, (cx + 0.07 * k, hy - 0.08 * k), (cx + 0.22 * k, hy - 0.22 * k), (cx + 0.13 * k, hy - 0.02 * k))
  }
  if hood {
    disc(s, cx, hy + 0.02, head-r * 0.8, fill: ink)
    disc(s, cx - 0.035 * k, hy + 0.02, 0.012, fill: white)
    disc(s, cx + 0.035 * k, hy + 0.02, 0.012, fill: white)
  } else {
    disc(s, cx, hy, head-r, fill: tone)
    eyes(s, cx, hy - 0.01, gap: 0.05 * k, r: 0.026 * k)
    grin(s, cx, hy + 0.05 * k, w: 0.045 * k)
  }
  if hat {
    poly(s, fill: ink, (cx - 0.2 * k, hy - head-r * 0.6), (cx + 0.2 * k, hy - head-r * 0.6), (cx + 0.02, top - 0.2 * k))
  }
  // Weapons in the right hand.
  let hx = cx + 0.25 * k
  let hy2 = hip - 0.02
  if blade {
    seg(s, hx, hy2, hx + 0.12 * k, hy2 - 0.3 * k, w: 2.4)
    seg(s, hx - 0.04, hy2 - 0.02, hx + 0.05, hy2 + 0.02, w: 2)
  }
  if club {
    seg(s, hx, hy2, hx + 0.08 * k, hy2 - 0.26 * k, w: 2)
    disc(s, hx + 0.09 * k, hy2 - 0.28 * k, 0.06 * k, fill: mid)
  }
}

#let critter(s, kind) = {
  if kind == "rat" {
    shadow(s, w: 0.3)
    place(curve(stroke: pen(s), curve.move((0.72 * s, 0.9 * s)),
                curve.cubic((0.95 * s, 0.85 * s), (0.95 * s, 0.6 * s), (0.85 * s, 0.55 * s))))
    oval(s, 0.5, 0.78, 0.24, 0.17, fill: mid)
    disc(s, 0.3, 0.68, 0.12, fill: mid)
    disc(s, 0.24, 0.55, 0.06, fill: light)
    disc(s, 0.38, 0.55, 0.06, fill: light)
    eyes(s, 0.29, 0.66, gap: 0.04, r: 0.022)
    disc(s, 0.19, 0.72, 0.02, fill: ink)
  } else if kind == "bat" {
    for (x, y) in ((0.3, 0.3), (0.68, 0.42), (0.45, 0.62)) {
      poly(s, fill: mid, (x, y), (x - 0.16, y - 0.08), (x - 0.12, y + 0.02), (x - 0.18, y + 0.06), (x, y + 0.06))
      poly(s, fill: mid, (x, y), (x + 0.16, y - 0.08), (x + 0.12, y + 0.02), (x + 0.18, y + 0.06), (x, y + 0.06))
      disc(s, x, y + 0.02, 0.05, fill: dark)
      disc(s, x - 0.018, y + 0.015, 0.01, fill: white)
      disc(s, x + 0.018, y + 0.015, 0.01, fill: white)
    }
  } else if kind == "spider" {
    seg(s, 0.5, 0.0, 0.5, 0.42)
    shadow(s, w: 0.3)
    for side in (-1, 1) {
      for i in range(4) {
        let y = 0.5 + i * 0.05
        seg(s, 0.5, y, 0.5 + side * 0.24, y - 0.06, w: 1.6)
        seg(s, 0.5 + side * 0.24, y - 0.06, 0.5 + side * (0.3 + i * 0.02), 0.9, w: 1.6)
      }
    }
    oval(s, 0.5, 0.6, 0.15, 0.14, fill: dark)
    disc(s, 0.5, 0.45, 0.08, fill: dark)
    for dx in (-0.04, -0.015, 0.015, 0.04) { disc(s, 0.5 + dx, 0.44, 0.012, fill: white) }
  } else if kind == "beetle" {
    shadow(s, w: 0.36)
    for side in (-1, 1) {
      for i in range(3) {
        seg(s, 0.5 + side * 0.1, 0.72 + i * 0.05, 0.5 + side * 0.36, 0.86 + i * 0.03, w: 1.6)
      }
    }
    oval(s, 0.5, 0.72, 0.3, 0.2, fill: mid)
    seg(s, 0.5, 0.52, 0.5, 0.92)
    disc(s, 0.5, 0.56, 0.1, fill: dark)
    poly(s, fill: light, (0.47, 0.5), (0.5, 0.26), (0.55, 0.5))
    eyes(s, 0.5, 0.58, gap: 0.045, r: 0.02)
  } else if kind == "mushroom" {
    shadow(s, w: 0.28)
    slab(s, 0.38, 0.52, 0.24, 0.44, fill: light, r: 0.08)
    for side in (-1, 1) { seg(s, 0.5 + side * 0.12, 0.62, 0.5 + side * 0.26, 0.8, w: 2.6) }
    place(curve(fill: mid, stroke: pen(s),
      curve.move((0.14 * s, 0.56 * s)),
      curve.cubic((0.14 * s, 0.2 * s), (0.86 * s, 0.2 * s), (0.86 * s, 0.56 * s)),
      curve.close()))
    for (x, y) in ((0.32, 0.4), (0.52, 0.32), (0.68, 0.44)) { disc(s, x, y, 0.04, fill: white) }
    eyes(s, 0.5, 0.66, gap: 0.05, r: 0.024)
  } else if kind == "chest" {
    shadow(s, w: 0.34)
    slab(s, 0.2, 0.62, 0.6, 0.34, fill: mid, r: 0.03)
    poly(s, fill: mid, (0.2, 0.62), (0.26, 0.4), (0.74, 0.4), (0.8, 0.62))
    for x in (0.3, 0.38, 0.46, 0.54, 0.62) { poly(s, fill: white, (x, 0.62), (x + 0.04, 0.72), (x + 0.08, 0.62)) }
    seg(s, 0.2, 0.62, 0.8, 0.62)
    slab(s, 0.46, 0.66, 0.08, 0.1, fill: light)
  } else if kind == "golem" {
    shadow(s, w: 0.34)
    for side in (-1, 1) { slab(s, 0.5 + side * 0.1 - 0.06, 0.72, 0.12, 0.24, fill: mid) }
    slab(s, 0.26, 0.38, 0.48, 0.36, fill: mid)
    for side in (-1, 1) { slab(s, 0.5 + side * 0.31 - 0.07, 0.4, 0.14, 0.34, fill: mid) }
    slab(s, 0.38, 0.16, 0.24, 0.22, fill: light)
    for (x, y) in ((0.3, 0.42), (0.7, 0.42), (0.3, 0.7), (0.7, 0.7)) { disc(s, x, y, 0.015, fill: ink) }
    slab(s, 0.42, 0.24, 0.16, 0.04, fill: ink, r: 0)
    disc(s, 0.5, 0.56, 0.06, fill: white)
  } else if kind == "wraith" {
    place(curve(fill: light, stroke: pen(s),
      curve.move((0.5 * s, 0.08 * s)),
      curve.cubic((0.8 * s, 0.08 * s), (0.78 * s, 0.6 * s), (0.82 * s, 0.86 * s)),
      curve.line((0.72 * s, 0.78 * s)), curve.line((0.62 * s, 0.88 * s)),
      curve.line((0.5 * s, 0.78 * s)), curve.line((0.38 * s, 0.88 * s)),
      curve.line((0.28 * s, 0.78 * s)), curve.line((0.18 * s, 0.86 * s)),
      curve.cubic((0.22 * s, 0.6 * s), (0.2 * s, 0.08 * s), (0.5 * s, 0.08 * s)),
      curve.close()))
    oval(s, 0.5, 0.3, 0.12, 0.13, fill: ink)
    disc(s, 0.46, 0.29, 0.018, fill: white)
    disc(s, 0.54, 0.29, 0.018, fill: white)
    for side in (-1, 1) { seg(s, 0.5 + side * 0.22, 0.45, 0.5 + side * 0.36, 0.56, w: 2) }
  }
}

#let prop(s, kind) = {
  if kind == "die" {
    shadow(s, w: 0.34)
    poly(s, fill: light, (0.25, 0.42), (0.5, 0.3), (0.75, 0.42), (0.5, 0.54))
    poly(s, fill: pale, (0.25, 0.42), (0.5, 0.54), (0.5, 0.94), (0.25, 0.8))
    poly(s, fill: white, (0.5, 0.54), (0.75, 0.42), (0.75, 0.8), (0.5, 0.94))
    disc(s, 0.5, 0.42, 0.025, fill: ink)
    eyes(s, 0.375, 0.64, gap: 0.04, r: 0.018, angry: false)
    seg(s, 0.34, 0.76, 0.41, 0.73)
    for (x, y) in ((0.57, 0.6), (0.68, 0.55), (0.57, 0.72), (0.68, 0.67), (0.57, 0.84), (0.68, 0.79)) {
      disc(s, x, y, 0.018, fill: ink)
    }
  } else if kind == "fountain" {
    shadow(s, w: 0.4)
    oval(s, 0.5, 0.86, 0.36, 0.1, fill: light)
    slab(s, 0.14, 0.86, 0.72, 0.1, fill: light, r: 0)
    oval(s, 0.5, 0.86, 0.3, 0.06, fill: mid, stroke: none)
    slab(s, 0.46, 0.5, 0.08, 0.34, fill: light, r: 0)
    oval(s, 0.5, 0.5, 0.16, 0.05, fill: light)
    for dx in (-0.12, 0.12) { seg(s, 0.5, 0.42, 0.5 + dx, 0.62) }
    seg(s, 0.5, 0.42, 0.5, 0.3)
  } else if kind == "mushrooms" {
    for (x, h, r) in ((0.3, 0.2, 0.1), (0.5, 0.32, 0.15), (0.72, 0.16, 0.09), (0.4, 0.12, 0.06)) {
      slab(s, x - r * 0.35, 0.96 - h, r * 0.7, h, fill: pale, r: 0.02)
      place(curve(fill: mid, stroke: pen(s),
        curve.move(((x - r) * s, (0.96 - h) * s)),
        curve.cubic(((x - r) * s, (0.96 - h - r * 1.4) * s), ((x + r) * s, (0.96 - h - r * 1.4) * s), ((x + r) * s, (0.96 - h) * s)),
        curve.close()))
      disc(s, x - r * 0.3, 0.96 - h - r * 0.5, r * 0.2, fill: white)
    }
  } else if kind == "bones" {
    shadow(s, w: 0.36)
    seg(s, 0.2, 0.92, 0.5, 0.84, w: 2.4)
    seg(s, 0.55, 0.94, 0.85, 0.88, w: 2.4)
    slab(s, 0.56, 0.62, 0.26, 0.26, fill: mid, r: 0.06)
    seg(s, 0.6, 0.66, 0.78, 0.66)
    disc(s, 0.36, 0.72, 0.13, fill: pale)
    disc(s, 0.31, 0.71, 0.035, fill: ink)
    disc(s, 0.41, 0.71, 0.035, fill: ink)
    slab(s, 0.3, 0.8, 0.12, 0.06, fill: pale, r: 0.01)
  } else if kind == "well" {
    shadow(s, w: 0.38)
    slab(s, 0.22, 0.62, 0.56, 0.34, fill: light, r: 0)
    for y in (0.73, 0.84) { seg(s, 0.22, y, 0.78, y, w: 0.6) }
    oval(s, 0.5, 0.62, 0.28, 0.07, fill: ink)
    seg(s, 0.26, 0.62, 0.26, 0.24, w: 1.6)
    seg(s, 0.74, 0.62, 0.74, 0.24, w: 1.6)
    poly(s, fill: mid, (0.18, 0.28), (0.5, 0.12), (0.82, 0.28))
    seg(s, 0.5, 0.3, 0.5, 0.52)
    slab(s, 0.46, 0.5, 0.08, 0.07, fill: mid, r: 0.01)
  } else if kind == "darts" {
    for (y, d) in ((0.3, 1), (0.48, -1), (0.62, 1), (0.42, 1)) {
      let x = if d == 1 { 0.18 + y * 0.3 } else { 0.82 - y * 0.2 }
      seg(s, x, y, x + d * 0.2, y, w: 1.4)
      poly(s, fill: ink, (x + d * 0.2, y - 0.025), (x + d * 0.26, y), (x + d * 0.2, y + 0.025))
      poly(s, fill: mid, (x, y), (x - d * 0.05, y - 0.04), (x - d * 0.02, y))
    }
    slab(s, 0.38, 0.86, 0.24, 0.1, fill: mid, r: 0.01)
  } else if kind == "pit" {
    oval(s, 0.5, 0.85, 0.4, 0.12, fill: ink)
    for x in (0.25, 0.35, 0.45, 0.55, 0.65, 0.75) {
      poly(s, fill: light, (x - 0.03, 0.9), (x, 0.78), (x + 0.03, 0.9))
    }
  } else if kind == "boulder" {
    shadow(s, w: 0.38)
    disc(s, 0.5, 0.6, 0.36, fill: mid)
    for (x1, y1, x2, y2) in ((0.3, 0.45, 0.42, 0.52), (0.58, 0.36, 0.66, 0.48), (0.5, 0.72, 0.64, 0.7)) {
      seg(s, x1, y1, x2, y2)
    }
    for y in (0.4, 0.6, 0.8) { seg(s, 0.02, y, 0.1, y, w: 1.4) }
  } else if kind == "gas" {
    for (x, y, r) in ((0.3, 0.75, 0.16), (0.55, 0.7, 0.2), (0.75, 0.8, 0.13), (0.45, 0.48, 0.15), (0.65, 0.4, 0.11)) {
      disc(s, x, y, r, fill: light)
    }
    for x in (0.25, 0.5, 0.75) { seg(s, x - 0.06, 0.96, x + 0.06, 0.96, w: 2) }
  } else if kind == "merchant" {
    shadow(s, w: 0.42)
    biped(s, size: 0.62, tone: light, ears: true, belly: true)
    slab(s, 0.12, 0.66, 0.76, 0.3, fill: light, r: 0.02)
    for x in (0.2, 0.36, 0.52, 0.68) { disc(s, x + 0.06, 0.62, 0.05, fill: mid) }
    for side in (0.12, 0.84) { seg(s, side + 0.02, 0.66, side + 0.02, 0.12, w: 1.4) }
    poly(s, fill: mid, (0.08, 0.2), (0.92, 0.2), (0.86, 0.06), (0.14, 0.06))
    for x in (0.25, 0.42, 0.58, 0.75) { seg(s, x, 0.06, x - 0.02, 0.2, w: 0.7) }
  } else if kind == "anvil" {
    shadow(s, w: 0.4)
    biped(s, size: 0.7, tone: mid, belly: true, club: true)
    poly(s, fill: dark, (0.06, 0.66), (0.5, 0.66), (0.44, 0.74), (0.38, 0.74), (0.38, 0.86), (0.46, 0.96), (0.1, 0.96), (0.18, 0.86), (0.18, 0.74))
    poly(s, fill: dark, (0.06, 0.66), (0.0, 0.66), (0.06, 0.71))
  } else if kind == "campfire" {
    shadow(s, w: 0.32)
    seg(s, 0.28, 0.94, 0.72, 0.84, w: 3)
    seg(s, 0.28, 0.84, 0.72, 0.94, w: 3)
    place(curve(fill: light, stroke: pen(s),
      curve.move((0.36 * s, 0.86 * s)),
      curve.cubic((0.3 * s, 0.6 * s), (0.5 * s, 0.6 * s), (0.48 * s, 0.4 * s)),
      curve.cubic((0.62 * s, 0.56 * s), (0.7 * s, 0.68 * s), (0.64 * s, 0.86 * s)),
      curve.close()))
    place(curve(fill: white, stroke: pen(s),
      curve.move((0.44 * s, 0.86 * s)),
      curve.cubic((0.42 * s, 0.74 * s), (0.5 * s, 0.7 * s), (0.5 * s, 0.62 * s)),
      curve.cubic((0.58 * s, 0.72 * s), (0.6 * s, 0.8 * s), (0.56 * s, 0.86 * s)),
      curve.close()))
  } else if kind == "cups" {
    biped(s, size: 0.56, tone: mid, ears: true)
    slab(s, 0.1, 0.74, 0.8, 0.06, fill: mid, r: 0)
    seg(s, 0.2, 0.8, 0.2, 0.96, w: 2)
    seg(s, 0.8, 0.8, 0.8, 0.96, w: 2)
    for x in (0.26, 0.5, 0.74) { poly(s, fill: light, (x - 0.07, 0.74), (x - 0.05, 0.6), (x + 0.05, 0.6), (x + 0.07, 0.74)) }
  } else if kind == "dragon" {
    for (x, y) in ((0.22, 0.92), (0.3, 0.88), (0.68, 0.9), (0.76, 0.93), (0.5, 0.94), (0.4, 0.9), (0.6, 0.88)) {
      oval(s, x, y, 0.06, 0.025, fill: light)
    }
    poly(s, fill: mid, (0.5, 0.6), (0.82, 0.4), (0.76, 0.6), (0.6, 0.66))
    oval(s, 0.5, 0.74, 0.26, 0.14, fill: mid)
    disc(s, 0.3, 0.7, 0.11, fill: mid)
    seg(s, 0.24, 0.7, 0.29, 0.71)
    seg(s, 0.33, 0.7, 0.38, 0.71)
    for (x, y, sz) in ((0.4, 0.5, 0.09), (0.48, 0.42, 0.07)) {
      at(s, x, y, text(sz * s, fill: dark, font: "DejaVu Sans Mono", weight: "bold")[z])
    }
  } else if kind == "witch" {
    biped(s, size: 0.8, tone: dark, hood: true, hat: true)
    oval(s, 0.3, 0.84, 0.18, 0.12, fill: ink)
    oval(s, 0.3, 0.73, 0.18, 0.04, fill: light)
    for (x, y, r) in ((0.26, 0.62, 0.03), (0.34, 0.55, 0.02), (0.29, 0.48, 0.015)) { disc(s, x, y, r, fill: white) }
  } else if kind == "gate" {
    slab(s, 0.22, 0.18, 0.56, 0.78, fill: light, r: 0)
    place(curve(fill: ink, stroke: pen(s),
      curve.move((0.3 * s, 0.96 * s)), curve.line((0.3 * s, 0.4 * s)),
      curve.cubic((0.3 * s, 0.22 * s), (0.7 * s, 0.22 * s), (0.7 * s, 0.4 * s)),
      curve.line((0.7 * s, 0.96 * s)), curve.close()))
    for x in (0.36, 0.43, 0.5, 0.57, 0.64) { seg(s, x, 0.32, x, 0.96, w: 1.4) }
    place(line(start: (0.3 * s, 0.6 * s), end: (0.7 * s, 0.6 * s), stroke: 0.025 * s + light))
    seg(s, 0.22, 0.18, 0.78, 0.18)
  }
}

// One drawing per encounter art key, in a box of size s. Art "monster" is
// a random monster, built from the parts in `m` (see monster.typ).
#let drawing(art, s, m: none) = figure-box(s, {
  if art == "monster" { monster(m, s) }
  else if art == "skeleton" { biped(s, size: 0.86, tone: pale, ribs: true, blade: true) }
  else if art == "cultist" { biped(s, size: 0.88, tone: dark, hood: true) }
  else if art == "troll" { biped(s, size: 1, tone: mid, ears: true, belly: true, club: true) }
  else if art == "bullgrim" { biped(s, size: 1.04, tone: dark, horns: true, ears: true, belly: true, club: true) }
  else if art == "troll-toll" { biped(s, size: 1, tone: mid, ears: true, belly: true) }
  else if art == "ghost" { critter(s, "wraith") }
  else if art in ("rat", "bat", "spider", "beetle", "mushroom", "chest", "golem", "wraith") {
    critter(s, art)
  } else if art == "troll" { biped(s, tone: mid) }
  else { prop(s, art) }
})

// Corridor --------------------------------------------------------------------

// A corridor seen from the middle of a room, looking the way it faces.
// `exits` holds the sides with a doorway: front, left, right, back, up, down.
// `label(side)` gives the marker content for each exit.
// `lock(side)` gives an optional badge drawn beside the marker.
#let corridor(w, h, exits, label, lock: _ => none, art: none, size: 0.5) = {
  let has(side) = exits.contains(side)
  let (bx0, bx1) = (w * 0.31, w * 0.69)
  let (by0, by1) = (h * 0.2, h * 0.62)
  let st = (paint: ink, thickness: 0.9pt, join: "round")
  let thin = (paint: mid, thickness: 0.6pt)

  box(width: w, height: h, clip: true, radius: 0.07 * w, stroke: 1.2pt + mid, fill: white, {
    // Ceiling, floor and walls.
    place(polygon(fill: pale, stroke: st, (0pt, 0pt), (w, 0pt), (bx1, by0), (bx0, by0)))
    place(polygon(fill: white, stroke: st, (0pt, h), (w, h), (bx1, by1), (bx0, by1)))
    place(polygon(fill: light, stroke: st, (0pt, 0pt), (bx0, by0), (bx0, by1), (0pt, h)))
    place(polygon(fill: light, stroke: st, (w, 0pt), (bx1, by0), (bx1, by1), (w, h)))
    // Beams where the room meets the corridor walls.
    for f in (0.12,) {
      let x0 = bx0 * f
      let x1 = w - bx0 * f
      let y0 = by0 * f
      let y1 = h - (h - by1) * f
      place(line(start: (x0, y0), end: (x0, y1), stroke: thin))
      place(line(start: (x1, y0), end: (x1, y1), stroke: thin))
      place(line(start: (x0, y0), end: (x1, y0), stroke: thin))
    }

    // Side doorways: a dark opening in the wall's middle.
    let side-door(dir) = {
      let (xa, xb) = if dir == -1 { (0.1, 0.22) } else { (0.9, 0.78) }
      let lerp(a, b, t) = a + (b - a) * t
      // Wall edge from outer (x=0 or w) to inner (bx0 or bx1).
      let x-at(t) = if dir == -1 { lerp(0pt, bx0, t) } else { lerp(w, bx1, t) }
      let top(t) = lerp(0pt, by0, t) + (lerp(h, by1, t) - lerp(0pt, by0, t)) * 0.22
      let bot(t) = lerp(h, by1, t)
      let (t0, t1) = (0.42, 0.72)
      place(polygon(fill: luma(160), stroke: st,
        (x-at(t0), top(t0)), (x-at(t1), top(t1)), (x-at(t1), bot(t1)), (x-at(t0), bot(t0))))
    }
    if has("left") { side-door(-1) }
    if has("right") { side-door(1) }

    // Back: a solid wall, or the corridor carrying on into the dark.
    if has("front") {
      let (cx0, cx1) = (w * 0.42, w * 0.58)
      let (cy0, cy1) = (h * 0.34, h * 0.5)
      place(polygon(fill: pale, stroke: st, (bx0, by0), (bx1, by0), (cx1, cy0), (cx0, cy0)))
      place(polygon(fill: white, stroke: st, (bx0, by1), (bx1, by1), (cx1, cy1), (cx0, cy1)))
      place(polygon(fill: light, stroke: st, (bx0, by0), (cx0, cy0), (cx0, cy1), (bx0, by1)))
      place(polygon(fill: light, stroke: st, (bx1, by0), (cx1, cy0), (cx1, cy1), (bx1, by1)))
      place(dx: cx0, dy: cy0, rect(width: cx1 - cx0, height: cy1 - cy0, fill: luma(150), stroke: st))
    } else {
      place(dx: bx0, dy: by0, rect(width: bx1 - bx0, height: by1 - by0, fill: luma(238), stroke: st))
      // A few stones.
      for (fx, fy, fw) in ((0.1, 0.25, 0.3), (0.55, 0.45, 0.28), (0.25, 0.7, 0.26)) {
        place(dx: bx0 + (bx1 - bx0) * fx, dy: by0 + (by1 - by0) * fy,
              rect(width: (bx1 - bx0) * fw, height: (by1 - by0) * 0.12, stroke: thin, radius: 1pt))
      }
    }

    // Ladders: up through a hatch in the ceiling, down through one in the floor.
    let ladder(x, y0, y1, rung) = {
      place(line(start: (x, y0), end: (x, y1), stroke: 1.2pt + ink))
      place(line(start: (x + rung, y0), end: (x + rung, y1), stroke: 1.2pt + ink))
      let n = 6
      for i in range(n) {
        let y = y0 + (y1 - y0) * (i + 0.5) / n
        place(line(start: (x, y), end: (x + rung, y), stroke: 1pt + ink))
      }
    }
    if has("up") {
      let x = w * 0.18
      place(polygon(fill: ink, stroke: st, (x - w * 0.03, h * 0.04), (x + w * 0.12, h * 0.04), (x + w * 0.1, h * 0.1), (x - w * 0.01, h * 0.1)))
      ladder(x, h * 0.07, h * 0.8, w * 0.07)
    }
    if has("down") {
      let x = w * 0.68
      place(polygon(fill: ink, stroke: st, (x, h * 0.8), (x + w * 0.2, h * 0.8), (x + w * 0.24, h * 0.92), (x - w * 0.02, h * 0.92)))
      ladder(x + w * 0.065, h * 0.78, h * 0.9, w * 0.07)
    }

    // The encounter stands in the middle of the floor.
    if art != none {
      let s = h * size
      place(dx: (w - s) / 2, dy: h * 0.86 - s, art(s))
    }

    // Exit markers: a numbered triangle pointing the way out.
    let marker(side) = {
      let m = calc.min(w, h) * 0.15
      let tri(pts) = polygon(fill: ink, stroke: none, ..pts)
      let shape = if side == "front" {
        tri(((0pt, m * 0.8), (m * 1.2, m * 0.8), (m * 0.6, 0pt)))
      } else if side == "back" {
        tri(((0pt, 0pt), (m * 1.2, 0pt), (m * 0.6, m * 0.8)))
      } else if side == "left" {
        tri(((m * 0.8, 0pt), (m * 0.8, m * 1.2), (0pt, m * 0.6)))
      } else if side == "right" {
        tri(((0pt, 0pt), (0pt, m * 1.2), (m * 0.8, m * 0.6)))
      } else {
        rect(width: m * 1.2, height: m * 0.8, radius: m * 0.15, fill: ink)
      }
      let (mw, mh) = if side in ("left", "right") { (m * 0.8, m * 1.2) } else { (m * 1.2, m * 0.8) }
      let (x, y) = if side == "front" { ((w - mw) / 2, 0pt) }
        else if side == "back" { ((w - mw) / 2, h - mh) }
        else if side == "left" { (0pt, (h - mh) / 2) }
        else if side == "right" { (w - mw, (h - mh) / 2) }
        else if side == "up" { (w * 0.18 + w * 0.035 - mw / 2, h * 0.12) }
        else { (w * 0.78 - mw / 2, h * 0.66) }
      let dy = if side == "front" { mh * 0.18 } else if side == "back" { -mh * 0.08 } else { 0pt }
      let dx = if side == "left" { mw * 0.12 } else if side == "right" { -mw * 0.12 } else { 0pt }
      place(dx: x, dy: y, box(width: mw, height: mh, {
        place(shape)
        place(dx: dx, dy: dy, box(width: mw, height: mh, align(center + horizon, label(side))))
      }))
      let badge = lock(side)
      if badge != none {
        if side in ("left", "right") {
          place(dx: if side == "left" { x + m * 0.05 } else { x - m * 0.65 }, dy: y + mh + m * 0.1, badge)
        } else {
          place(dx: x + mw + m * 0.15, dy: y + mh * 0.15, badge)
        }
      }
    }
    for side in exits { marker(side) }
  })
}
