// Random monsters, assembled from Kenney's Monster Builder Pack (CC0, see
// monsters/LICENSE.txt). prolog/games/labyrinth/monster.pl picks the parts;
// this file knows where each one goes.
//
// Layout works in the pack's default sprite pixels (the PNGs are the 2x
// set, so they stay sharp in print); the finished figure is scaled into the
// usual unit box of size s, standing on the floor line.

#let dir = "/monsters/"

// Sprite sizes, from the pack's spritesheet_default.xml (same in every colour).
#let sizes = (
  body: (A: (165, 165), B: (192, 192), C: (141, 194), D: (174, 182), E: (132, 250), F: (170, 236)),
  arm: (A: (82, 176), B: (51, 161), C: (98, 181), D: (92, 197), E: (71, 149)),
  leg: (A: (72, 167), B: (55, 149), C: (79, 124), D: (71, 122), E: (102, 109)),
  detail: (
    ear: (38, 44), ear_round: (54, 54), eye: (58, 78),
    horn_large: (40, 42), horn_small: (31, 27),
    antenna_large: (38, 58), antenna_small: (26, 42),
  ),
  face: (
    eye_angry_blue: (64, 58), eye_angry_green: (60, 55), eye_angry_red: (60, 55),
    eye_cute_dark: (64, 69), eye_cute_light: (64, 69), eye_human: (64, 69),
    eye_human_blue: (64, 69), eye_human_green: (64, 69), eye_human_red: (64, 69),
    eye_psycho_dark: (64, 69), eye_psycho_light: (64, 69), eye_red: (64, 58), eye_yellow: (64, 69),
    eyebrowA: (49, 32), eyebrowB: (52, 33), eyebrowC: (57, 33),
    mouthA: (70, 34), mouthB: (70, 34), mouthC: (78, 38), mouthD: (66, 27), mouthE: (62, 39),
    mouthF: (74, 42), mouthG: (50, 44), mouthH: (78, 52), mouthI: (74, 42), mouthJ: (72, 48),
    mouth_closed_fangs: (52, 20), mouth_closed_happy: (80, 24), mouth_closed_sad: (52, 20),
    mouth_closed_teeth: (66, 26),
    nose_brown: (54, 48), nose_green: (53, 59), nose_red: (47, 51), nose_yellow: (46, 38),
  ),
)

// Where the joint ball sits in each limb sprite, as fractions of its size.
// Sprites face right: they're used as-is on the monster's left (our right)
// and mirrored on the other side.
#let joints = (
  arm: (A: (0.35, 0.17), B: (0.33, 0.1), C: (0.29, 0.16), D: (0.33, 0.155), E: (0.32, 0.1)),
  leg: (A: (0.35, 0.15), B: (0.28, 0.1), C: (0.26, 0.165), D: (0.3, 0.17), E: (0.24, 0.23)),
  detail: (
    ear: (0.25, 0.85), ear_round: (0.4, 0.7), eye: (0.15, 0.92),
    horn_large: (0.3, 0.85), horn_small: (0.3, 0.8),
    antenna_large: (0.2, 0.9), antenna_small: (0.2, 0.92),
  ),
)

// Per body, as fractions of its size: eye line, mouth line, usable face
// width, shoulder (x from centre, y), hip (x from centre, y) and the top
// details (x from centre, y).
#let bodies = (
  A: (eyes: 0.36, mouth: 0.66, face: 0.8, shoulder: (0.42, 0.5), hip: (0.26, 0.9), top: (0.3, 0.08)),
  B: (eyes: 0.38, mouth: 0.66, face: 0.7, shoulder: (0.4, 0.52), hip: (0.22, 0.88), top: (0.26, 0.1)),
  C: (eyes: 0.34, mouth: 0.6, face: 0.74, shoulder: (0.38, 0.5), hip: (0.2, 0.9), top: (0.22, 0.08)),
  D: (eyes: 0.4, mouth: 0.68, face: 0.74, shoulder: (0.4, 0.58), hip: (0.26, 0.9), top: (0.26, 0.12)),
  E: (eyes: 0.27, mouth: 0.48, face: 0.82, shoulder: (0.42, 0.42), hip: (0.24, 0.94), top: (0.26, 0.06)),
  F: (eyes: 0.3, mouth: 0.52, face: 0.64, shoulder: (0.34, 0.45), hip: (0.2, 0.94), top: (0.2, 0.08)),
)

// A part: sprite name, top-left corner and size in pixels, mirrored or not.
// Mirrored parts flip about their own centre; rot turns them after that.
#let part(name, x, y, w, h, flip: false, rot: 0deg) = (name: name, x: x, y: y, w: w, h: h, flip: flip, rot: rot)

// A limb or detail pair: the joint of the right-hand one lands on (jx, jy),
// the left one is its mirror image about the body's centre line cx.
#let pair(name, size, joint, cx, jx, jy, scale: 1) = {
  let (w, h) = (size.at(0) * scale, size.at(1) * scale)
  let (ax, ay) = joint
  let right = part(name, jx - ax * w, jy - ay * h, w, h)
  let left = part(name, 2 * cx - jx - (1 - ax) * w, jy - ay * h, w, h, flip: true)
  (left, right)
}

// A face sprite scaled to width w, centred on (x, y).
#let feature(name, x, y, w, flip: false, rot: 0deg) = {
  let (nw, nh) = sizes.face.at(name)
  let h = w * nh / nw
  part(name, x - w / 2, y - h / 2, w, h, flip: flip, rot: rot)
}

#let parts(m) = {
  let (bw, bh) = sizes.body.at(m.body)
  let b = bodies.at(m.body)
  let cx = bw / 2
  let back = ()
  if m.detail != none {
    let (tx, ty) = b.top
    back += pair("detail_" + m.color + "_" + m.detail, sizes.detail.at(m.detail),
                 joints.detail.at(m.detail), cx, cx + tx * bw, ty * bh)
  }
  if m.arms != none {
    let (sx, sy) = b.shoulder
    back += pair("arm_" + m.limbs + m.arms, sizes.arm.at(m.arms), joints.arm.at(m.arms),
                 cx, cx + sx * bw, sy * bh)
  }
  if m.legs != none {
    let (hx, hy) = b.hip
    back += pair("leg_" + m.limbs + m.legs, sizes.leg.at(m.legs), joints.leg.at(m.legs),
                 cx, cx + hx * bw, hy * bh)
  }

  // The face: one big eye, a pair, or a pair under a third.
  let fw = b.face * bw
  let ey = b.eyes * bh
  let (ew, spots) = if m.eyes == 1 { (0.5 * fw, ((0, 0),)) }
    else if m.eyes == 2 { (0.4 * fw, ((-0.24, 0), (0.24, 0))) }
    else { (0.3 * fw, ((-0.3, 0.04), (0.3, 0.04), (0, -0.12))) }
  let front = ()
  for (dx, dy) in spots {
    // Slanted eyes are drawn for our right; mirror the ones on the left.
    front.push(feature(m.eye, cx + dx * fw, ey + dy * fw, ew, flip: dx < 0))
  }
  // Brows over the bottom row of eyes: angry ones dip towards the middle,
  // raised ones lift. The sprites are drawn for our left eye.
  if m.brows != none {
    let angry = m.brows == "angry"
    let brow = if m.eyes == 1 { "eyebrowC" } else if angry { "eyebrowA" } else { "eyebrowB" }
    let (nw, nh) = sizes.face.at(m.eye)
    let top = ey - ew * nh / nw / 2
    let (lift, tilt) = if angry { (0.0, 16deg) } else { (0.06, -10deg) }
    for (dx, dy) in spots.filter(((_, dy)) => dy >= 0) {
      let side = if dx > 0 { -1 } else { 1 }
      front.push(feature(brow, cx + dx * fw, top + (dy - lift) * fw, ew * 0.85,
                         flip: dx > 0, rot: if dx == 0 { 0deg } else { side * tilt }))
    }
  }
  let my = b.mouth * bh
  if m.nose != none { front.push(feature(m.nose, cx, (ey + my) / 2 + 0.04 * fw, 0.26 * fw)) }
  front.push(feature(m.mouth, cx, my, 0.5 * fw))

  back + (part("body_" + m.color + m.body, 0, 0, bw, bh),) + front
}

// The monster in a unit box of size s, feet on the floor line.
#let monster(m, s) = box(width: s, height: s, {
  let ps = parts(m)
  let x0 = calc.min(..ps.map(p => p.x))
  let x1 = calc.max(..ps.map(p => p.x + p.w))
  let y0 = calc.min(..ps.map(p => p.y))
  let y1 = calc.max(..ps.map(p => p.y + p.h))
  let k = calc.min(m.size * 0.94 * s / (y1 - y0), 0.98 * s / (x1 - x0))
  let ox = (s - (x1 - x0) * k) / 2 - x0 * k
  let oy = 0.97 * s - y1 * k
  // A soft floor shadow.
  let sw = calc.min(0.9, (x1 - x0) * k / s * 0.7)
  place(dx: (1 - sw) / 2 * s, dy: 0.93 * s, ellipse(width: sw * s, height: 0.08 * s, fill: luma(200)))
  for p in ps {
    let img = image(dir + p.name + ".png", width: p.w * k, height: p.h * k)
    let img = if p.flip { scale(x: -100%, img) } else { img }
    place(dx: ox + p.x * k, dy: oy + p.y * k,
          if p.rot != 0deg { rotate(p.rot, img) } else { img })
  }
})
