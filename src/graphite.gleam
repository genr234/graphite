import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import graphite/catalog.{type Title}
import graphite/cover
import graphite/icons
import graphite/ui
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

// MODEL -----------------------------------------------------------------------

pub type Model {
  Model(
    route: Route,
    /// Seed of the notebooks on the home shelf; opening one uses it.
    shelf_seed: Int,
    game: String,
    seed: String,
    paper: String,
    theme: String,
    status: Status,
    svg: String,
    /// JSON page outline of the preview, for its page rail.
    stops: String,
  )
}

pub type Route {
  Home
  Play(Title)
}

pub type Status {
  Rendering
  Ready
  Failed(String)
}

fn init(_) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      route: Home,
      shelf_seed: random_number(),
      game: "golf",
      seed: random_seed(),
      paper: "a4",
      theme: "parkland",
      status: Rendering,
      svg: "",
      stops: "[]",
    )
  let #(model, effect) = navigate(model, current_hash())
  #(model, effect.batch([effect, watch_hash()]))
}

fn random_number() -> Int {
  int.random(36 * 36 * 36 * 36 * 36 * 36)
}

fn random_seed() -> String {
  int.to_base36(random_number())
}

// ROUTING ---------------------------------------------------------------------

/// Routes are hashes so the app works on any static host:
/// "#/" is the shelf, "#/golf" a generator, "#/golf/SEED" a given notebook.
fn navigate(model: Model, hash: String) -> #(Model, Effect(Msg)) {
  let #(id, seed) = case string.split(hash, "/") {
    [id, seed, ..] if seed != "" -> #(id, Some(seed))
    [id, ..] -> #(id, None)
    [] -> #("", None)
  }
  case catalog.find(id) {
    Ok(title) -> {
      let seed = option.unwrap(seed, model.seed)
      rerender(Model(..model, route: Play(title), game: title.id, seed:))
    }
    Error(Nil) -> #(Model(..model, route: Home), scroll_to_top())
  }
}

fn watch_hash() -> Effect(Msg) {
  use dispatch <- effect.from
  use hash <- on_hash_change
  dispatch(BrowserChangedHash(hash))
}

fn scroll_to_top() -> Effect(Msg) {
  use _ <- effect.from
  scroll_top()
}

@external(javascript, "./graphite_ffi.mjs", "current_hash")
fn current_hash() -> String

@external(javascript, "./graphite_ffi.mjs", "on_hash_change")
fn on_hash_change(callback: fn(String) -> Nil) -> Nil

@external(javascript, "./graphite_ffi.mjs", "replace_hash")
fn replace_hash(hash: String) -> Nil

@external(javascript, "./graphite_ffi.mjs", "scroll_top")
fn scroll_top() -> Nil

// UPDATE ----------------------------------------------------------------------

pub type Msg {
  BrowserChangedHash(String)
  UserChangedSeed(String)
  UserChangedPaper(String)
  UserChangedTheme(String)
  UserPressedKeyInSeed(String)
  UserClickedRandomSeed
  UserClickedGenerate
  UserClickedDownload
  EngineRenderedPreview(Result(#(String, String), String))
  EngineSavedPdf(Result(Nil, String))
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    BrowserChangedHash(hash) -> navigate(model, hash)
    UserChangedSeed(seed) -> #(Model(..model, seed:), effect.none())
    UserChangedPaper(paper) -> rerender(Model(..model, paper:))
    UserChangedTheme(theme) -> rerender(Model(..model, theme:))
    UserClickedRandomSeed -> rerender(Model(..model, seed: random_seed()))
    UserClickedGenerate | UserPressedKeyInSeed("Enter") -> rerender(model)
    UserPressedKeyInSeed(_) -> #(model, effect.none())
    UserClickedDownload -> #(model, download(model))
    EngineRenderedPreview(Ok(#(svg, stops))) -> #(
      Model(..model, status: Ready, svg:, stops:),
      effect.none(),
    )
    EngineRenderedPreview(Error(reason)) | EngineSavedPdf(Error(reason)) -> #(
      Model(..model, status: Failed(reason)),
      effect.none(),
    )
    EngineSavedPdf(Ok(Nil)) -> #(model, effect.none())
  }
}

fn rerender(model: Model) -> #(Model, Effect(Msg)) {
  let model = Model(..model, status: Rendering)
  #(model, effect.batch([render(model), remember_seed(model)]))
}

/// Keeps the address bar on the notebook being shown, so it can be shared.
/// Replacing the hash doesn't fire hashchange, so this doesn't loop.
fn remember_seed(model: Model) -> Effect(Msg) {
  use _ <- effect.from
  replace_hash("/" <> model.game <> "/" <> model.seed)
}

fn render(model: Model) -> Effect(Msg) {
  use dispatch <- effect.from
  use result <- preview(model.game, model.seed, model.paper, model.theme)
  dispatch(EngineRenderedPreview(result))
}

fn download(model: Model) -> Effect(Msg) {
  use dispatch <- effect.from
  use result <- download_pdf(model.game, model.seed, model.paper, model.theme)
  dispatch(EngineSavedPdf(result))
}

@external(javascript, "./graphite_ffi.mjs", "preview")
fn preview(
  game: String,
  seed: String,
  paper: String,
  theme: String,
  callback: fn(Result(#(String, String), String)) -> Nil,
) -> Nil

@external(javascript, "./graphite_ffi.mjs", "download_pdf")
fn download_pdf(
  game: String,
  seed: String,
  paper: String,
  theme: String,
  callback: fn(Result(Nil, String)) -> Nil,
) -> Nil

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  case model.route {
    Home -> view_home(model)
    Play(title) -> view_generator(model, title)
  }
}

// HOME ------------------------------------------------------------------------

fn view_home(model: Model) -> Element(Msg) {
  html.main([attribute.class("app page home")], [
    ui.shelf(
      list.index_map(catalog.titles(), fn(title, i) {
        let seed = int.to_base36(model.shelf_seed + i)
        let href = "#/" <> title.id <> "/" <> seed
        ui.shelf_item(ui.notebook(
          title.name,
          seed,
          cover.view(title.cover, model.shelf_seed + i),
          href,
        ))
      }),
    ),
  ])
}

// GENERATOR -------------------------------------------------------------------

fn view_generator(model: Model, title: Title) -> Element(Msg) {
  html.main([attribute.class("app page")], [
    html.header([attribute.class("console plate")], [
      html.div([attribute.class("nameplate")], [
        ui.round_link(icons.ArrowLeft, "All notebooks", "#/"),
        html.div([attribute.class("nameplate-text")], [
          html.h1([], [html.text(title.name)]),
          html.span([attribute.class("label")], [
            html.text(title.players <> " · " <> title.dice),
          ]),
        ]),
      ]),
      ui.field("Seed", [
        html.div([attribute.class("cluster")], [
          ui.readout(model.seed, "Seed", UserChangedSeed, [
            event.on_keydown(UserPressedKeyInSeed),
          ]),
          ui.round_key(icons.Shuffle, "Shuffle seed", UserClickedRandomSeed),
          html.span([attribute.class("bezel")], [
            ui.key(
              "Generate",
              UserClickedGenerate,
              icon: Some(icons.Reload),
              attrs: [],
            ),
          ]),
        ]),
      ]),
      case title.themes {
        [] -> element.none()
        themes ->
          ui.field("Theme", [
            ui.bank("Theme", themes, model.theme, UserChangedTheme),
          ])
      },
      ui.field("Paper", [
        ui.bank(
          "Paper",
          [#("a4", "A4"), #("us-letter", "Letter"), #("pocket-a4", "Pocket")],
          model.paper,
          UserChangedPaper,
        ),
      ]),
      html.div([attribute.class("output")], [
        view_status(model.status),
        ui.signal_key(
          "Download PDF",
          UserClickedDownload,
          icon: Some(icons.Download),
          enabled: model.status == Ready,
        ),
      ]),
    ]),
    view_error(model.status),
    view_print_hint(model.paper),
    html.section([attribute.class("tray well")], [
      ui.scroller(model.stops, busy: model.status == Rendering, children: [
        element.unsafe_raw_html(
          "",
          "div",
          [attribute.class("sheet")],
          model.svg,
        ),
      ]),
    ]),
  ])
}

fn view_print_hint(paper: String) -> Element(Msg) {
  case paper {
    "pocket-a4" ->
      html.p([attribute.class("hint")], [
        html.text(
          "Print double-sided, flipping on the long edge. Cut each sheet along the dashed line, "
          <> "stack the halves in order (top half, bottom half, next sheet…) each inside the last, "
          <> "then fold and staple along the middle.",
        ),
      ])
    _ -> element.none()
  }
}

fn view_status(status: Status) -> Element(Msg) {
  case status {
    Rendering -> ui.status("Rendering")
    Ready -> ui.status("Ready")
    Failed(_) -> ui.status("Error")
  }
}

fn view_error(status: Status) -> Element(Msg) {
  case status {
    Failed(reason) -> html.p([attribute.class("error")], [html.text(reason)])
    _ -> element.none()
  }
}
