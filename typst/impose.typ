// Pocket booklet: imposes an A6 notebook PDF onto A4 sheets, four pages a side.
//
// Print double-sided (flip on the long edge), cut every sheet along the dashed
// line, then stack the halves in order — top half of sheet 1, its bottom half,
// top half of sheet 2, … — each one *inside* the previous, and fold.
//
// Inputs: src (path of the A6 PDF), pages (its page count).

#let src = sys.inputs.src
#let n = int(sys.inputs.pages)
#let total = calc.ceil(n / 8) * 8        // two folios per sheet, four pages each
#let folios = total / 4

#set page(paper: "a4", margin: 0pt, fill: white)

#let (pw, ph) = (105mm, 148mm)           // A6
#let half = 148.5mm                      // A4 split into two A5 landscape halves

#let a6(p) = if p <= n {
  image(src, page: p, width: pw, height: ph)
}

// Folio k (0 = outermost) carries pages N-2k | 2k+1 outside and 2k+2 | N-2k-1
// inside. Seen from the back after a long-edge flip, left and right swap, so
// the inner pair reads 2k+2 on the left.
#let outside(k) = (total - 2 * k, 2 * k + 1)
#let inside(k) = (2 * k + 2, total - 2 * k - 1)

#let side(top, bottom, marks) = {
  for (row, pair) in ((0, top), (1, bottom)) {
    let dy = row * half + (half - ph) / 2
    place(dx: 0mm, dy: dy, a6(pair.at(0)))
    place(dx: pw, dy: dy, a6(pair.at(1)))
  }
  if marks {
    let mark = (paint: luma(170), thickness: 0.4pt, dash: "dashed")
    place(dy: half, line(length: 210mm, stroke: mark))
    place(dx: 4mm, dy: half - 3.2mm, text(6pt, fill: luma(150))[✂ cut])
    for y in (half - 6mm, half + 2mm) {
      place(dx: pw, dy: y, line(start: (0mm, 0mm), end: (0mm, 4mm), stroke: 0.4pt + luma(170)))
    }
  }
}

#for s in range(int(folios / 2)) {
  let (top, bottom) = (2 * s, 2 * s + 1)
  side(outside(top), outside(bottom), true)
  pagebreak()
  side(inside(top), inside(bottom), false)
  if s < folios / 2 - 1 { pagebreak() }
}
