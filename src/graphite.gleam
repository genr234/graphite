import gleam/int
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
  Model(game: String, seed: String, paper: String, status: Status, svg: String)
}

pub type Status {
  Rendering
  Ready
  Failed(String)
}

fn init(_) -> #(Model, Effect(Msg)) {
  let model =
    Model(game: "golf", seed: random_seed(), paper: "a4", status: Rendering, svg: "")
  #(model, render(model))
}

fn random_seed() -> String {
  int.random(36 * 36 * 36 * 36 * 36 * 36) |> int.to_base36
}

// UPDATE ----------------------------------------------------------------------

pub type Msg {
  UserChangedSeed(String)
  UserChangedPaper(String)
  UserClickedRandomSeed
  UserClickedGenerate
  UserClickedDownload
  EngineRenderedPreview(Result(String, String))
  EngineSavedPdf(Result(Nil, String))
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserChangedSeed(seed) -> #(Model(..model, seed:), effect.none())
    UserChangedPaper(paper) -> rerender(Model(..model, paper:))
    UserClickedRandomSeed -> rerender(Model(..model, seed: random_seed()))
    UserClickedGenerate -> rerender(model)
    UserClickedDownload -> #(model, download(model))
    EngineRenderedPreview(Ok(svg)) -> #(
      Model(..model, status: Ready, svg:),
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
  #(model, render(model))
}

fn render(model: Model) -> Effect(Msg) {
  use dispatch <- effect.from
  use result <- preview(model.game, model.seed, model.paper)
  dispatch(EngineRenderedPreview(result))
}

fn download(model: Model) -> Effect(Msg) {
  use dispatch <- effect.from
  use result <- download_pdf(model.game, model.seed, model.paper)
  dispatch(EngineSavedPdf(result))
}

@external(javascript, "./graphite_ffi.mjs", "preview")
fn preview(
  game: String,
  seed: String,
  paper: String,
  callback: fn(Result(String, String)) -> Nil,
) -> Nil

@external(javascript, "./graphite_ffi.mjs", "download_pdf")
fn download_pdf(
  game: String,
  seed: String,
  paper: String,
  callback: fn(Result(Nil, String)) -> Nil,
) -> Nil

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  html.main([attribute.class("app")], [
    html.header([attribute.class("toolbar")], [
      html.h1([], [html.text("Graphite")]),
      html.label([], [
        html.text("Seed"),
        html.input([
          attribute.value(model.seed),
          attribute.spellcheck(False),
          event.on_input(UserChangedSeed),
        ]),
      ]),
      html.button([event.on_click(UserClickedRandomSeed)], [html.text("Shuffle")]),
      html.button([event.on_click(UserClickedGenerate)], [html.text("Generate")]),
      html.select([event.on_change(UserChangedPaper)], [
        paper_option(model, "a4", "A4"),
        paper_option(model, "us-letter", "Letter"),
      ]),
      html.button(
        [
          attribute.class("primary"),
          attribute.disabled(model.status != Ready),
          event.on_click(UserClickedDownload),
        ],
        [html.text("Download PDF")],
      ),
    ]),
    view_status(model.status),
    element.unsafe_raw_html("", "div", [attribute.class("preview")], model.svg),
  ])
}

fn paper_option(model: Model, value: String, label: String) -> Element(Msg) {
  html.option(
    [attribute.value(value), attribute.selected(model.paper == value)],
    label,
  )
}

fn view_status(status: Status) -> Element(Msg) {
  case status {
    Rendering -> html.p([attribute.class("status")], [html.text("Rendering…")])
    Ready -> element.none()
    Failed(reason) ->
      html.p([attribute.class("status error")], [html.text(reason)])
  }
}
