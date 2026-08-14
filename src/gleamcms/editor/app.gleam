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

pub fn render() -> String {
  let names = theme_provider.theme_names()
  let names_json =
    "[" <> string.join(list.map(names, fn(n) { "\"" <> n <> "\"" }), ",") <> "]"
  element.to_string(
    html.div([attribute.id("app"), attribute.data("themes", names_json)], [
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/static/editor.css"),
      ]),
      view(Model("", "", "", Draft, "content", "Default Dark", False, "")),
      html.script(
        [attribute.type_("module"), attribute.src("/static/editor.js")],
        "",
      ),
    ]),
  )
}

pub type Model {
  Model(
    title: String,
    slug: String,
    content: String,
    status: PostStatus,
    section_type: String,
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
  SetSectionType(String)
  SetTheme(String)
  Save
  Generate
  GenerateDone(String)
}

pub fn init(_flags) -> #(Model, Effect(Msg)) {
  #(
    Model("", "", "", Draft, "content", "Default Dark", False, ""),
    effect.none(),
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SetTitle(t) -> #(Model(..model, title: t), effect.none())
    SetSlug(s) -> #(Model(..model, slug: s), effect.none())
    SetContent(c) -> #(Model(..model, content: c), effect.none())
    SetStatus(s) -> #(Model(..model, status: s), effect.none())
    SetSectionType(st) -> #(Model(..model, section_type: st), effect.none())
    SetTheme(name) -> #(Model(..model, selected_theme: name), effect.none())
    Save -> #(model, effect.none())
    Generate -> #(model, generate_effect(model))
    GenerateDone(slug) -> #(
      Model(..model, generated: True, generated_slug: slug),
      effect.none(),
    )
  }
}

fn generate_effect(model: Model) -> Effect(Msg) {
  use dispatch <- effect.from
  dispatch(GenerateDone(model.slug))
  Nil
}

pub fn main() {
  let app = lustre.application(init, update, view_empty)
  let _ = lustre.start(app, "#app", Nil)
  Nil
}

fn view_empty(model: Model) -> Element(Msg) {
  view(model)
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("studio-root")], [
    // Header Bar
    html.header([attribute.class("studio-header")], [
      html.a([attribute.href("/admin"), attribute.class("studio-logo")], [
        element.text("Gleam"),
        html.span([], [element.text("Studio")]),
      ]),
      html.div([attribute.class("studio-header-actions")], [
        html.button(
          [
            event.on_click(Save),
            attribute.class("btn-secondary"),
            attribute.id("btn-save"),
          ],
          [element.text("💾 Save Fact")],
        ),
        html.button(
          [
            event.on_click(Generate),
            attribute.class("btn-primary"),
            attribute.id("btn-generate"),
          ],
          [element.text("⚡ 1-Click Publish & Build")],
        ),
        html.a(
          [
            attribute.href("/sites"),
            attribute.class("btn-secondary"),
            attribute.id("btn-view-sites"),
          ],
          [element.text("🌐 View Sites")],
        ),
      ]),
    ]),
    // Dual Pane Container
    html.div([attribute.class("studio-container")], [
      // Left: Visual Controls & Content Editor
      html.div([attribute.class("editor-pane")], [
        // 1. Click-to-Insert Block Templates
        html.div([attribute.class("block-library")], [
          html.div([attribute.class("section-title")], [
            element.text("Click to Insert Block Template"),
          ]),
          html.div([attribute.class("chip-grid")], [
            html.button(
              [
                attribute.class("chip-btn"),
                attribute.data("block", "hero"),
                attribute.id("block-hero"),
              ],
              [element.text("🚀 Hero Banner")],
            ),
            html.button(
              [
                attribute.class("chip-btn"),
                attribute.data("block", "features"),
                attribute.id("block-features"),
              ],
              [element.text("🌟 Feature Grid")],
            ),
            html.button(
              [
                attribute.class("chip-btn"),
                attribute.data("block", "stats"),
                attribute.id("block-stats"),
              ],
              [element.text("📊 Stats Counter")],
            ),
            html.button(
              [
                attribute.class("chip-btn"),
                attribute.data("block", "testimonial"),
                attribute.id("block-testimonial"),
              ],
              [element.text("💬 Testimonial")],
            ),
            html.button(
              [
                attribute.class("chip-btn"),
                attribute.data("block", "pricing"),
                attribute.id("block-pricing"),
              ],
              [element.text("💰 Pricing Table")],
            ),
            html.button(
              [
                attribute.class("chip-btn"),
                attribute.data("block", "article"),
                attribute.id("block-article"),
              ],
              [element.text("📝 Article")],
            ),
          ]),
        ]),
        // 2. Clickable Formatting Ribbon
        html.div([attribute.class("format-ribbon")], [
          html.button(
            [
              attribute.class("format-btn"),
              attribute.data("fmt", "bold"),
              attribute.id("fmt-bold"),
            ],
            [element.text("B")],
          ),
          html.button(
            [
              attribute.class("format-btn"),
              attribute.data("fmt", "italic"),
              attribute.id("fmt-italic"),
            ],
            [element.text("I")],
          ),
          html.button(
            [
              attribute.class("format-btn"),
              attribute.data("fmt", "code"),
              attribute.id("fmt-code"),
            ],
            [element.text("Code")],
          ),
          html.button(
            [
              attribute.class("format-btn"),
              attribute.data("fmt", "h1"),
              attribute.id("fmt-h1"),
            ],
            [element.text("H1")],
          ),
          html.button(
            [
              attribute.class("format-btn"),
              attribute.data("fmt", "h2"),
              attribute.id("fmt-h2"),
            ],
            [element.text("H2")],
          ),
          html.button(
            [
              attribute.class("format-btn"),
              attribute.data("fmt", "quote"),
              attribute.id("fmt-quote"),
            ],
            [element.text("Quote")],
          ),
          html.button(
            [
              attribute.class("format-btn"),
              attribute.data("fmt", "list"),
              attribute.id("fmt-list"),
            ],
            [element.text("List")],
          ),
          html.button(
            [
              attribute.class("format-btn"),
              attribute.data("fmt", "link"),
              attribute.id("fmt-link"),
            ],
            [element.text("Link")],
          ),
          html.button(
            [
              attribute.class("format-btn"),
              attribute.data("fmt", "image"),
              attribute.id("fmt-image"),
            ],
            [element.text("Image")],
          ),
        ]),
        // 3. Form Meta Fields
        html.div([attribute.class("field-group")], [
          html.label([attribute.class("field-label")], [element.text("Title")]),
          html.input([
            attribute.value(model.title),
            event.on_input(SetTitle),
            attribute.class("input-text"),
            attribute.id("field-title"),
            attribute.placeholder("e.g. Next-Gen Sovereign Engine"),
          ]),
        ]),
        html.div([attribute.class("field-group")], [
          html.label([attribute.class("field-label")], [element.text("Slug")]),
          html.input([
            attribute.value(model.slug),
            event.on_input(SetSlug),
            attribute.class("input-text"),
            attribute.id("field-slug"),
            attribute.placeholder("e.g. sovereign-engine"),
          ]),
        ]),
        html.div([attribute.class("field-group")], [
          html.label([attribute.class("field-label")], [
            element.text("Section Type"),
          ]),
          html.select(
            [
              event.on_input(SetSectionType),
              attribute.class("select-input"),
              attribute.id("field-section-type"),
            ],
            [
              html.option([attribute.value("hero")], "Hero Section"),
              html.option([attribute.value("features")], "Features Section"),
              html.option([attribute.value("stats")], "Stats Section"),
              html.option([attribute.value("cta")], "CTA Section"),
              html.option([attribute.value("content")], "Standard Content"),
            ],
          ),
        ]),
        // 4. Content Area
        html.div([attribute.class("field-group")], [
          html.label([attribute.class("field-label")], [
            element.text("Content (Markdown / AST)"),
          ]),
          html.textarea(
            [
              attribute.value(model.content),
              event.on_input(SetContent),
              attribute.class("textarea-content"),
              attribute.id("field-content"),
              attribute.placeholder(
                "Click a block template above or start typing...",
              ),
            ],
            "",
          ),
        ]),
        // 5. One-Click AI Inspiration Chips
        html.div([attribute.class("ai-designer-box")], [
          html.div([attribute.class("section-title")], [
            element.text("1-Click AI Inspiration"),
          ]),
          html.div([attribute.class("chip-grid")], [
            html.button(
              [
                attribute.class("chip-btn ai-chip"),
                attribute.data("prompt", "Cyberpunk Neon SaaS Landing Page"),
              ],
              [element.text("⚡ Cyberpunk")],
            ),
            html.button(
              [
                attribute.class("chip-btn ai-chip"),
                attribute.data("prompt", "Minimalist Editorial Dark Theme"),
              ],
              [element.text("✨ Minimalist")],
            ),
            html.button(
              [
                attribute.class("chip-btn ai-chip"),
                attribute.data("prompt", "Arctic Clean Ice Glassmorphism"),
              ],
              [element.text("❄️ Arctic Clean")],
            ),
            html.button(
              [
                attribute.class("chip-btn ai-chip"),
                attribute.data("prompt", "Emerald Forest Organic Sustainable"),
              ],
              [element.text("🌲 Emerald")],
            ),
            html.button(
              [
                attribute.class("chip-btn"),
                attribute.id("btn-surprise-theme"),
              ],
              [element.text("🎲 Surprise Palette")],
            ),
          ]),
          html.input([
            attribute.type_("hidden"),
            attribute.id("ai-prompt"),
          ]),
        ]),
        // 6. Theme Picker & Swatches
        html.div([attribute.class("theme-box")], [
          html.div([attribute.class("section-title")], [
            element.text("51 Curated Themes"),
          ]),
          html.select(
            [
              event.on_input(SetTheme),
              attribute.class("select-input"),
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
      ]),
      // Right: Live Real-Time Preview Pane
      html.div([attribute.class("preview-pane")], [
        html.div([attribute.class("preview-header")], [
          html.span([], [element.text("Live Real-Time Preview")]),
          html.div([attribute.class("chip-grid")], [
            html.button(
              [attribute.class("chip-btn active"), attribute.id("view-desktop")],
              [element.text("🖥️ Desktop")],
            ),
            html.button(
              [attribute.class("chip-btn"), attribute.id("view-mobile")],
              [element.text("📱 Mobile")],
            ),
          ]),
        ]),
        html.iframe([
          attribute.class("preview-window"),
          attribute.id("preview-iframe"),
          attribute.src("about:blank"),
        ]),
      ]),
    ]),
  ])
}
