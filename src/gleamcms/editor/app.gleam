import gleam/list
import gleamcms/builder/theme as theme_provider
import gleamcms/db/post.{type PostStatus, Draft}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn render() -> String {
  let model = Model("", "", "", Draft, "content", "Default Dark", False, "")
  element.to_string(view(model))
}

pub fn render_with_template(
  title: String,
  slug: String,
  content: String,
  section_type: String,
) -> String {
  let model =
    Model(title, slug, content, Draft, section_type, "Default Dark", False, "")
  element.to_string(view(model))
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

pub fn view(model: Model) -> Element(Nil) {
  let names = theme_provider.theme_names()
  let theme_options =
    list.map(names, fn(name) { html.option([attribute.value(name)], name) })

  html.main([], [
    html.header([], [
      html.h1([], [element.text("GleamCMS Studio")]),
      html.p([], [
        element.text(
          "Pure Semantic Web Hypermedia Engine (Zero CSS, Zero JavaScript).",
        ),
      ]),
      html.nav([], [
        html.a([attribute.href("/admin")], [element.text("Editor")]),
        element.text(" | "),
        html.a([attribute.href("/sites")], [element.text("Generated Sites")]),
        element.text(" | "),
        html.a([attribute.href("/health")], [element.text("Health Check")]),
      ]),
    ]),
    html.hr([]),
    // 1. Clickable Block Templates (Pure Hypermedia)
    html.section([], [
      html.h2([], [element.text("1-Click Block Templates")]),
      html.p([], [
        element.text(
          "Click any template link below to populate the editor instantly:",
        ),
      ]),
      html.ul([], [
        html.li([], [
          html.a([attribute.href("/admin?template=hero")], [
            element.text("🚀 Hero Banner Template"),
          ]),
        ]),
        html.li([], [
          html.a([attribute.href("/admin?template=features")], [
            element.text("🌟 Feature Grid Template"),
          ]),
        ]),
        html.li([], [
          html.a([attribute.href("/admin?template=stats")], [
            element.text("📊 Stats Counter Template"),
          ]),
        ]),
        html.li([], [
          html.a([attribute.href("/admin?template=testimonial")], [
            element.text("💬 Testimonial Quote Template"),
          ]),
        ]),
        html.li([], [
          html.a([attribute.href("/admin?template=pricing")], [
            element.text("💰 Pricing Table Template"),
          ]),
        ]),
        html.li([], [
          html.a([attribute.href("/admin?template=article")], [
            element.text("📝 Longform Article Template"),
          ]),
        ]),
      ]),
    ]),
    html.hr([]),
    // 2. Native HTML Form for Saving Post / Transacting Facts
    html.section([], [
      html.h2([], [element.text("Post Editor")]),
      html.form([attribute.method("POST"), attribute.action("/api/save")], [
        html.fieldset([], [
          html.legend([], [element.text("Post Metadata")]),
          html.p([], [
            html.label([], [
              element.text("Title: "),
              html.input([
                attribute.type_("text"),
                attribute.name("title"),
                attribute.value(model.title),
                attribute.required(True),
              ]),
            ]),
          ]),
          html.p([], [
            html.label([], [
              element.text("Slug: "),
              html.input([
                attribute.type_("text"),
                attribute.name("slug"),
                attribute.value(model.slug),
                attribute.required(True),
              ]),
            ]),
          ]),
          html.p([], [
            html.label([], [
              element.text("Section Type: "),
              html.select([attribute.name("section_type")], [
                html.option([attribute.value("hero")], "Hero Section"),
                html.option([attribute.value("features")], "Features Section"),
                html.option([attribute.value("stats")], "Stats Section"),
                html.option([attribute.value("cta")], "CTA Section"),
                html.option([attribute.value("content")], "Standard Content"),
              ]),
            ]),
          ]),
          html.p([], [
            html.label([], [
              element.text("Status: "),
              html.select([attribute.name("status")], [
                html.option([attribute.value("published")], "Published"),
                html.option([attribute.value("draft")], "Draft"),
                html.option([attribute.value("archived")], "Archived"),
              ]),
            ]),
          ]),
        ]),
        html.fieldset([], [
          html.legend([], [element.text("Markdown Content (AST Tree)")]),
          html.p([], [
            html.textarea(
              [
                attribute.name("content"),
                attribute.rows(14),
                attribute.cols(80),
                attribute.placeholder("Write Markdown content here..."),
              ],
              model.content,
            ),
          ]),
        ]),
        html.p([], [
          html.button([attribute.type_("submit")], [
            element.text("💾 Transact Fact into AaronDB"),
          ]),
        ]),
      ]),
    ]),
    html.hr([]),
    // 3. Native HTML Form for Atomic Static Site Generation
    html.section([], [
      html.h2([], [element.text("Atomic Static Site Generator")]),
      html.form([attribute.method("POST"), attribute.action("/api/generate")], [
        html.fieldset([], [
          html.legend([], [element.text("Site Build Configuration")]),
          html.p([], [
            html.label([], [
              element.text("Select Theme: "),
              html.select([attribute.name("theme")], theme_options),
            ]),
            element.text(" "),
            html.button([attribute.type_("submit")], [
              element.text("⚡ Generate Static Projections"),
            ]),
          ]),
        ]),
      ]),
    ]),
    html.hr([]),
    html.footer([], [
      html.p([], [
        element.text(
          "GleamCMS — 100% Pure Gleam on Erlang/BEAM. Zero CSS, Zero JavaScript.",
        ),
      ]),
    ]),
  ])
}
