#import "lib/themes.typ": themes
#import "lib/course.typ": hole-map, swatch, tile, slope-angle, pick

// Notebook data comes from prolog/graphite.pl as a JSON string input.
#let data = json(bytes(sys.inputs.data))
#let theme = themes.at(sys.inputs.at("theme", default: "parkland"))
#let paper = sys.inputs.at("paper", default: "a4")
#let ink = theme.ink
#let faint = luma(150)
#let soft = luma(225)
#let mono = "DejaVu Sans Mono"

// Pocket (A6) pages get imposed into a booklet by impose.typ. Spacing scales
// by `k` and text by `kt`: half-size text would be unreadable, so it shrinks less.
#let pocket = paper == "a6"
#let k = if pocket { 0.6 } else { 1 }
#let kt = if pocket { 0.75 } else { 1 }

#set page(
  paper: paper,
  fill: white,
  margin: if pocket { (x: 6mm, top: 6mm, bottom: 9mm) } else { (x: 1.5cm, top: 1.4cm, bottom: 1.6cm) },
  footer: context {
    set text(7pt * kt, fill: faint)
    [GOLF · #theme.name · seed #data.seed]
    h(1fr)
    counter(page).display()
  },
)
#set text(size: 10pt * kt, fill: ink)

#let title(size, body) = text(size * kt, font: mono, weight: "bold", body)
#let pill(body, width: 4cm) = box(width: width * k, height: 1.1cm * k, radius: 0.55cm * k,
  fill: soft, inset: (x: 0.4cm * k), align(right + horizon, body))
#let circles(n) = stack(dir: ltr, spacing: 0.22cm * k,
  ..range(n).map(_ => circle(radius: 0.25cm * k, stroke: 0.8pt + ink)))

// A rounded badge filled with a patch of the theme's rough, washed out so the
// text reads. Tiles overlap a hair to hide seams between neighbouring images.
#let badge(size, body) = {
  let spec = if theme.terrain == none { none } else { theme.terrain.r }
  let n = 7
  let t = size / n
  box(width: size, height: size, radius: 22%, clip: true, fill: rgb("#e3f1d8"), {
    if spec != none {
      for y in range(n) {
        for x in range(n) {
          let name = if type(spec) == dictionary { spec.autotile + "-c" } else { pick(spec, x, y) }
          place(dx: x * t, dy: y * t, tile(theme, name, t + 0.4pt))
        }
      }
    }
    place(rect(width: size, height: size, stroke: none, fill: white.transparentize(30%)))
    box(width: size, height: size, align(center + horizon, body))
  })
}

// Preview outline: one stop per page section, read by the app's page rail
// (web/ui/scroller.js). `mark` is "major" for a section start, else "minor".
#let stop(label, short, group: none, mark: "minor") = context [
  #metadata((page: here().page(), label: label, short: short, group: group, mark: mark)) <stop>
]

// Cover ---------------------------------------------------------------------

#page(footer: none, align(center + horizon, {
  stop("Cover", "◆", mark: "major")
  text(48pt * kt, font: mono, weight: "bold", tracking: 0.08em)[GOLF]
  v(0.4cm * k)
  text(11pt * kt, fill: faint)[#theme.name courses · seed #data.seed]
  v(1.5cm * k)
  for course in data.courses {
    text(13pt * kt, font: mono)[#course.name]
    v(0.2cm * k)
  }
}))

// Rules ---------------------------------------------------------------------

#let icon(name, angle: 0deg) = box(baseline: 25%, tile(theme, name, 1.1em, angle: angle))
#let section(body) = {
  v(0.5em)
  text(11pt * kt, font: mono, weight: "bold", body)
  v(0.1em)
}

#pagebreak()
#stop("How to play", "?", mark: "major")
#title(24pt)[How to play]
#v(0.3cm * k)
#set par(justify: true, spacing: 0.75em)
#columns(if pocket { 1 } else { 2 }, gutter: 0.8cm)[
  #set text(9.5pt * kt)

  #section[The goal]
  Get your ball from the tee #icon(theme.tee) into the hole #icon(theme.cup) in as few
  strokes as you can. Every hole is a par 6. All you need is a pencil, plus a
  six-sided die if you play Dice GOLF.

  #section[Taking a stroke]
  Choose one of the eight directions: straight up, down, left, right or diagonal.
  The ball travels in a straight line for exactly the distance of your stroke.
  Draw that line, then draw a small circle where the ball stops. You can hit back
  the way you came if you need to.

  The ball can't stop in water or trees, and it can't leave the page. It can fly
  over water, but it only clears trees when you hit from the fairway.

  #section[Putting]
  Instead of a full stroke you may always putt: move the ball one square. You can
  even roll the die first and then decide to putt.

  #section[Holing out]
  The ball drops when it stops on the hole. It also drops if its line passes over
  the hole and stops on the very next square. Any further than that and it rolls
  on past.

  #section[Slopes #icon(theme.arrow, angle: slope-angle.e)]
  If the ball stops on an arrow it rolls one square the way the arrow points:
  extend your line, it's not a new stroke. It keeps rolling while it lands on
  more arrows. Ignore an arrow that would roll it into water, trees or off the
  page. If two arrows point at each other, the ball stops after the first roll.
  A slope can roll the ball into the hole.

  #section[Dice GOLF]
  Roll the die: that's how many squares the ball travels. Add 1 when hitting from
  the fairway, subtract 1 from sand (a 1 in sand means you putt).

  - *Tee shot:* don't like your first roll? Roll once more, but you must keep the
    second result.
  - *Mulligans:* each course gives you six re-rolls to use whenever you like. Again,
    the new roll stands. Tick them off on the course page.
  - *Harder:* pick your direction before you roll.

  #section[Speed GOLF]
  No die needed. Choose a club for each stroke:

  - *Driver:* 6 squares. Only from the fairway, and it can fly over trees.
  - *Iron:* 3 squares, or 2 from sand. Never over trees.
  - *Putter:* 1 square, from anywhere.

  #if not pocket { colbreak() }
  #section[The course]
  #set par(justify: false)
  #table(
    columns: (auto, auto, 1fr, 1fr),
    stroke: (x, y) => if y > 0 { (top: 0.4pt + faint) },
    inset: (x: 4pt * kt, y: 5pt * kt),
    align: (center + horizon, left + horizon, left + horizon, left + horizon),
    [], [], text(8pt * kt, fill: faint)[*Dice*], text(8pt * kt, fill: faint)[*Speed*],
    swatch(theme, "r", 1.6em), [*Rough*], [Roll as is], [Iron or putter],
    swatch(theme, "f", 1.6em), [*Fairway* \ #text(8pt * kt)[and the green]], [Roll +1, fly over trees], [Driver, iron or putter],
    swatch(theme, "s", 1.6em), [*Sand*], [Roll −1], [Iron goes 2],
    swatch(theme, "w", 1.6em), [*Water*], table.cell(colspan: 2)[Fly over it, but never stop in it],
    swatch(theme, "t", 1.6em), [*Trees*], table.cell(colspan: 2)[Never stop in them. Only fairway shots fly over],
  )

  #section[Scoring]
  Count the lines you drew: that's your score for the hole (slope rolls don't
  count). Write it at the top of the hole page, and add up the round in the Total
  Score on the course page.

  #section[Bigfoot #icon(theme.bigfoot)]
  Some notebooks have a Bigfoot hiding on one hole. Spot it and you earn a free
  Mulligan for that hole.

  #section[Playing together]
  Everyone plays on the same page in a different colour; Dice GOLF works best.
  Agree who tees off first. After that, whoever is farthest from the hole always
  plays next.

  #section[What's on the map]
  #grid(columns: (auto, 1fr), column-gutter: 0.6em, row-gutter: 0.5em, align: horizon,
    icon(theme.tee), [Tee: start here],
    icon(theme.cup), [Hole],
    icon(theme.arrow), [Slope],
  )
]

// Courses -------------------------------------------------------------------

#for course in data.courses {
  let total-par = course.holes.map(h => h.par).sum()

  // Course page: name badge, Mulligans, total score.
  pagebreak(weak: true)
  stop(course.name, str(course.number), group: "Course " + str(course.number), mark: "major")
  set par(justify: false)
  align(center + horizon, {
    title(22pt)[Course \##course.number]
    v(1.2cm * k)
    badge(9.5cm * k, pad(x: 0.8cm * k, title(28pt, course.name)))
    v(1cm * k)
    title(11pt)[Mulligans]
    v(0.15cm * k)
    circles(6)
    v(0.7cm * k)
    title(16pt)[Total Score]
    v(0.2cm * k)
    pill(text(11pt * kt, font: mono, fill: faint)[/#total-par])
  })

  // One page per hole.
  for hole in course.holes {
    pagebreak()
    stop("Hole " + str(hole.number), str(hole.number), group: course.name)
    grid(columns: (1fr, auto), align: bottom,
      [#text(8pt * kt, fill: faint)[#course.name] \ #title(20pt)[Hole #hole.number]],
      [#text(9pt * kt, font: mono)[Par #hole.par] #h(0.6em)
       #pill(width: 2.6cm, text(9pt * kt, font: mono, fill: faint)[strokes])],
    )
    v(0.4cm * k)
    layout(size => {
      // layout() reports the whole content area; leave room for the header above.
      let cell = calc.min(size.width / hole.width, (size.height - 2.4cm * k) / hole.height)
      align(center, hole-map(hole, theme, cell))
    })
  }
}
