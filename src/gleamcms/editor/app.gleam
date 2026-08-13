import gleam/list
import gleam/string
import gleamcms/builder/theme as theme_provider
import gleamcms/db/post.{type PostStatus, Draft}
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

// ---------------------------------------------------------------------------
// Server-side render entry point
// ---------------------------------------------------------------------------

pub fn render() -> String {
  let names = theme_provider.theme_names()
  let names_json =
    "[" <> string.join(list.map(names, fn(n) { "\"" <> n <> "\"" }), ",") <> "]"
  element.to_string(
    html.div([attribute.id("app")], [
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/static/editor.css"),
      ]),
      view(Model("", "", "", Draft, "Default Dark", False, "")),
      html.script([], "window.__GLEAMCMS_THEMES__=" <> names_json <> ";"),
      html.script(
        [attribute.type_("module"), attribute.src("/static/editor.js")],
        "",
      ),
    ]),
  )
}

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

pub type Model {
  Model(
    title: String,
    slug: String,
    content: String,
    status: PostStatus,
    selected_theme: String,
    generated: Bool,
    generated_slug: String,
  )
}

pub type Msg {
  SetTitle(String)
  SetSlug(String)
  SetContent(String)
  SetStatus(PostStatus)
  SetTheme(String)
  Save
  Generate
  GenerateDone(String)
}

// ---------------------------------------------------------------------------
// Init / Update
// ---------------------------------------------------------------------------

pub fn init(_flags) -> #(Model, Effect(Msg)) {
  #(Model("", "", "", Draft, "Default Dark", False, ""), effect.none())
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SetTitle(t) -> #(Model(..model, title: t), effect.none())
    SetSlug(s) -> #(Model(..model, slug: s), effect.none())
    SetContent(c) -> #(Model(..model, content: c), effect.none())
    SetStatus(s) -> #(Model(..model, status: s), effect.none())
    SetTheme(name) -> #(Model(..model, selected_theme: name), effect.none())
    Save -> #(model, save_effect(model))
    Generate -> #(model, generate_effect(model))
    GenerateDone(slug) -> #(
      Model(..model, generated: True, generated_slug: slug),
      effect.none(),
    )
  }
}

fn save_effect(_model: Model) -> Effect(Msg) {
  // Persistence is performed client-side: the save button handler in
  // theme_script POSTs the model to /api/save. This effect intentionally does
  // nothing — the old version built a JSON body and discarded it, and
  // dispatching Save here would recurse (Save -> save_effect -> Save ...).
  effect.none()
}

fn generate_effect(model: Model) -> Effect(Msg) {
  use dispatch <- effect.from
  dispatch(GenerateDone(model.slug))
  Nil
}

// ---------------------------------------------------------------------------
// Main (browser entrypoint)
// ---------------------------------------------------------------------------

pub fn main() {
  let app = lustre.application(init, update, view_empty)
  let _ = lustre.start(app, "#app", Nil)
  Nil
}

fn view_empty(model: Model) -> Element(Msg) {
  view(model)
}

// ---------------------------------------------------------------------------
// View
// ---------------------------------------------------------------------------

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("editor-container")], [
    html.h1([], [element.text("GleamCMS Editor")]),

    // Title
    html.div([attribute.class("form-group")], [
      html.label([], [element.text("Title")]),
      html.input([
        attribute.value(model.title),
        event.on_input(SetTitle),
        attribute.class("title-input"),
        attribute.id("field-title"),
      ]),
    ]),

    // Slug
    html.div([attribute.class("form-group")], [
      html.label([], [element.text("Slug")]),
      html.input([
        attribute.value(model.slug),
        event.on_input(SetSlug),
        attribute.class("slug-input"),
        attribute.id("field-slug"),
      ]),
    ]),

    // Content
    html.div([attribute.class("form-group")], [
      html.label([], [element.text("Content")]),
      html.textarea(
        [
          attribute.value(model.content),
          event.on_input(SetContent),
          attribute.class("content-area"),
          attribute.id("field-content"),
        ],
        "",
      ),
    ]),

    // Status
    html.div([attribute.class("form-group")], [
      html.label([], [element.text("Status")]),
      html.select(
        [
          event.on_input(fn(v) { SetStatus(post.string_to_status(v)) }),
          attribute.class("status-select"),
          attribute.id("field-status"),
        ],
        [
          html.option([attribute.value("draft")], "Draft"),
          html.option([attribute.value("published")], "Published"),
          html.option([attribute.value("archived")], "Archived"),
        ],
      ),
    ]),

    // AI Designer
    html.div([attribute.class("form-group ai-section")], [
      html.label([], [element.text("AI Theme Designer ✨")]),
      html.div([attribute.class("ai-row")], [
        html.input([
          attribute.placeholder("e.g. Neon Horizon, Arctic Snow..."),
          attribute.class("ai-input"),
          attribute.id("ai-prompt"),
        ]),
        html.button(
          [
            attribute.class("ai-btn"),
            attribute.id("ai-btn"),
          ],
          [element.text("Design")],
        ),
      ]),
    ]),

    // Theme Picker
    html.div([attribute.class("form-group")], [
      html.label([], [element.text("Theme")]),
      html.select(
        [
          attribute.class("theme-select"),
          attribute.id("theme-picker"),
        ],
        [
          html.option(
            [attribute.value(model.selected_theme)],
            model.selected_theme,
          ),
        ],
      ),
    ]),

    // Action row
    html.div([attribute.class("action-row")], [
      html.button(
        [
          event.on_click(Save),
          attribute.class("save-btn"),
          attribute.id("btn-save"),
        ],
        [element.text("Transact Fact")],
      ),
      html.button(
        [
          event.on_click(Generate),
          attribute.class("generate-btn"),
          attribute.id("btn-generate"),
        ],
        [element.text("⚡ Generate Site")],
      ),
    ]),

    // Generated link banner (hidden until generated)
    html.div(
      [
        attribute.class("generated-link"),
        attribute.id("generated-link"),
        attribute.style("display", case model.generated {
          True -> "block"
          False -> "none"
        }),
      ],
      [
        element.text("✅ Sites generated! "),
        html.a(
          [
            attribute.href("/sites"),
            attribute.id("view-sites-link"),
          ],
          [element.text("🌐 View All Sites")],
        ),
      ],
    ),
  ])
}
// ---------------------------------------------------------------------------
