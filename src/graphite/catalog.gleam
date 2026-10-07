//// The notebooks Graphite can print. Only playable titles are listed; add a
//// title here once its generator and Typst template exist.

import gleam/list
import graphite/cover.{type Cover}

pub type Title {
  Title(
    /// Matches prolog/games/<id>.pl and typst/<id>.typ.
    id: String,
    name: String,
    players: String,
    dice: String,
    contents: String,
    pitch: String,
    cover: Cover,
    /// Visual themes as value-label pairs; empty when the title has one look.
    themes: List(#(String, String)),
  )
}

pub fn titles() -> List(Title) {
  [
    Title(
      id: "golf",
      name: "Golf",
      players: "Solo",
      dice: "1 d6",
      contents: "3 courses × 18 holes",
      pitch: "Plot every shot across a fresh course: pick a direction, roll for "
        <> "distance, and thread the ball past water, sand and trees. Par is "
        <> "six. Can you beat it?",
      cover: cover.Golf,
      themes: [
        #("parkland", "Parkland"),
        #("desert", "Desert"),
        #("island", "Island"),
        #("plain", "Plain"),
      ],
    ),
    Title(
      id: "dungeon",
      name: "Dungeon",
      players: "Solo",
      dice: "1 d6",
      contents: "30 floors, 5 shops",
      pitch: "Roll to move: odd goes diagonal, even goes straight, and walls "
        <> "turn you aside. Grab coins, dodge monsters, find hearts and take "
        <> "the stairs down to the treasure.",
      cover: cover.Dungeon,
      themes: [],
    ),
    Title(
      id: "labyrinth",
      name: "Labyrinth",
      players: "Solo",
      dice: "1 d6",
      contents: "50 rooms on 2 levels",
      pitch: "A gamebook maze: every page is a room. Map it as you go, fight "
        <> "what lurks in the dark, buy a better weapon, find both keys and "
        <> "beat the Bullgrim to escape.",
      cover: cover.Labyrinth,
      themes: [],
    ),
  ]
}

pub fn find(id: String) -> Result(Title, Nil) {
  list.find(titles(), fn(title) { title.id == id })
}
