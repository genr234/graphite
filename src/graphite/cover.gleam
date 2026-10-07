//// Procedural notebook covers: small pixel scenes built from the Typst theme
//// tiles (typst/themes/), so every visit shows a different notebook.

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import graphite/rng.{type Rng}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// Covers are 7 × 10 tiles, close to the A6 page ratio.
const cols = 7

const rows = 10

const theme = "parkland"

pub type Cover {
  Golf
  Labyrinth
}

/// The cover scene for `seed`. Scenes never animate or take input.
pub fn view(cover: Cover, seed: Int) -> Element(msg) {
  case cover {
    Golf -> golf(seed)
    Labyrinth -> labyrinth(seed)
  }
}

type Ground {
  Rough(variant: Int)
  Fairway
  Sand(piece: String)
  Water(piece: String)
}

type Cell {
  Cell(ground: Ground, sprite: Option(String))
}

// GOLF ------------------------------------------------------------------------

/// A golf hole seen from above: a tee at the bottom, a dogleg fairway up to
/// the green, a bunker beside the green, a pond and scattered trees.
fn golf(seed: Int) -> Element(msg) {
  let r = rng.new(seed)
  let #(tee_x, r) = rng.between(r, 1, 5)
  let #(flag_x, r) = rng.between(r, 1, 5)
  let #(bend_x, r) = rng.between(r, 1, 5)
  let #(bend_y, r) = rng.between(r, 4, 6)
  let #(bunker_y, r) = rng.between(r, 0, 2)
  let #(pond_y, r) = rng.between(r, 4, 6)

  // Centre of the fairway on each row: tee → bend → green.
  let centre = fn(y) {
    case y >= bend_y {
      True -> lerp(tee_x, bend_x, 8 - y, 8 - bend_y)
      False -> lerp(bend_x, flag_x, bend_y - y, bend_y - 1)
    }
  }

  let fairway =
    list.flat_map(span(1, 8), fn(y) {
      list.map([-1, 0, 1], fn(dx) { #(centre(y) + dx, y) })
    })
  let green =
    list.flat_map(span(0, 2), fn(y) {
      list.map([-1, 0, 1], fn(dx) { #(flag_x + dx, y) })
    })
  let bunker_x = case flag_x <= 3 {
    True -> flag_x + 2
    False -> flag_x - 3
  }
  let pond_x = case bend_x <= 3 {
    True -> 4
    False -> 0
  }

  let #(grounds, r) = rough(r)
  let grounds =
    grounds
    |> paint(list.append(fairway, green), fn(_) { Fairway })
    |> paint(rect(bunker_x, bunker_y, 2, 2), fn(xy) {
      Sand(piece(xy, bunker_x, bunker_y, 2, 2))
    })
    |> paint(rect(pond_x, pond_y, 3, 2), fn(xy) {
      Water(piece(xy, pond_x, pond_y, 3, 2))
    })

  let #(_, cells) =
    list.map_fold(grid(), r, fn(r, xy) {
      let assert Ok(ground) = dict.get(grounds, xy)
      case ground {
        _ if xy == #(tee_x, 8) -> #(r, Cell(ground, Some("tee")))
        _ if xy == #(flag_x, 1) -> #(r, Cell(ground, Some("flag")))
        Rough(_) -> {
          let #(tree, r) = rng.chance(r, 35)
          let #(kind, r) = rng.between(r, 1, 3)
          case tree {
            True -> #(r, Cell(ground, Some("tree-" <> int.to_string(kind))))
            False -> #(r, Cell(ground, None))
          }
        }
        _ -> #(r, Cell(ground, None))
      }
    })

  view_cells(cells)
}

fn rough(r: Rng) -> #(Dict(#(Int, Int), Ground), Rng) {
  let #(r, pairs) =
    list.map_fold(grid(), r, fn(r, xy) {
      let #(n, r) = rng.int(r, 4)
      let variant = case n {
        0 -> 2
        _ -> 1
      }
      #(r, #(xy, Rough(variant)))
    })
  #(dict.from_list(pairs), r)
}

// LABYRINTH -------------------------------------------------------------------

type Passage {
  North
  East
  Closed
}

/// A maze seen from above, entered at the bottom-left corner. Each cell opens
/// north or east at random (a binary-tree maze), so every cell connects.
fn labyrinth(seed: Int) -> Element(msg) {
  let #(_, passages) =
    list.map_fold(grid(), rng.new(seed), fn(r, xy) {
      let #(north, r) = rng.chance(r, 50)
      let passage = case xy.0 == cols - 1, xy.1 == 0 {
        True, True -> Closed
        True, False -> North
        False, True -> East
        False, False if north -> North
        False, False -> East
      }
      #(r, #(xy, passage))
    })

  html.div(
    [attribute.class("cover cover--maze"), attribute.aria_hidden(True)],
    list.map(passages, fn(cell) {
      let #(#(x, y), passage) = cell
      let walls = [
        #("wall-n", passage != North),
        #("wall-e", passage != East),
        #("wall-s", y == rows - 1 && x != 0),
        #("wall-w", x == 0),
        #("lair", x == cols - 1 && y == 0),
      ]
      html.div([attribute.classes([#("maze-cell", True), ..walls])], [])
    }),
  )
}

// GEOMETRY --------------------------------------------------------------------

fn grid() -> List(#(Int, Int)) {
  use y <- list.flat_map(span(0, rows - 1))
  use x <- list.map(span(0, cols - 1))
  #(x, y)
}

/// `from..to`, both inclusive.
fn span(from: Int, to: Int) -> List(Int) {
  int.range(from: to, to: from - 1, with: [], run: list.prepend)
}

fn rect(x: Int, y: Int, w: Int, h: Int) -> List(#(Int, Int)) {
  use dy <- list.flat_map(span(0, h - 1))
  use dx <- list.map(span(0, w - 1))
  #(x + dx, y + dy)
}

/// Paints cells that fall inside the cover; the rest are clipped.
fn paint(
  grounds: Dict(#(Int, Int), Ground),
  cells: List(#(Int, Int)),
  ground: fn(#(Int, Int)) -> Ground,
) -> Dict(#(Int, Int), Ground) {
  use grounds, xy <- list.fold(cells, grounds)
  case dict.has_key(grounds, xy) {
    True -> dict.insert(grounds, xy, ground(xy))
    False -> grounds
  }
}

/// The 3×3 autotile piece ("nw", "n", …, "c") for a cell of a rectangle.
fn piece(xy: #(Int, Int), x: Int, y: Int, w: Int, h: Int) -> String {
  let row = case xy.1 {
    _ if xy.1 == y -> "n"
    _ if xy.1 == y + h - 1 -> "s"
    _ -> ""
  }
  let col = case xy.0 {
    _ if xy.0 == x -> "w"
    _ if xy.0 == x + w - 1 -> "e"
    _ -> ""
  }
  case row <> col {
    "" -> "c"
    p -> p
  }
}

fn lerp(from: Int, to: Int, step: Int, steps: Int) -> Int {
  case steps <= 0 {
    True -> to
    False -> from + { to - from } * step / steps
  }
}

// VIEW ------------------------------------------------------------------------

fn view_cells(cells: List(Cell)) -> Element(msg) {
  html.div(
    [attribute.class("cover"), attribute.aria_hidden(True)],
    list.index_map(cells, fn(cell, i) {
      html.div(
        [attribute.style("background-image", layers(cell, i / cols))],
        [],
      )
    }),
  )
}

/// CSS background layers, topmost first: sprite, mowing stripe, ground.
fn layers(cell: Cell, y: Int) -> String {
  let ground = case cell.ground {
    Rough(variant) -> "rough-" <> int.to_string(variant)
    Fairway -> "fairway"
    Sand(piece) -> "sand-" <> piece
    Water(piece) -> "water-" <> piece
  }
  let stripe = case cell.ground {
    Fairway -> {
      let alpha = case y % 2 {
        0 -> "0.22"
        _ -> "0.1"
      }
      let white = "rgb(255 255 255 / " <> alpha <> ")"
      Some("linear-gradient(" <> white <> ", " <> white <> ")")
    }
    _ -> None
  }
  [option.map(cell.sprite, tile), stripe, Some(tile(ground))]
  |> option.values
  |> string.join(", ")
}

fn tile(name: String) -> String {
  "url(\"" <> tile_url(theme, name) <> "\")"
}

@external(javascript, "../graphite_ffi.mjs", "tile_url")
fn tile_url(theme: String, name: String) -> String
