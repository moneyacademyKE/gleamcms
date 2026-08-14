import gleam/list
import gleam/string
import gleamcms/content/markdown
import gleamcms/db/post.{type Post}
import gleamcms/theme.{type Theme, Theme}

pub type ThemeConfig {
  ThemeConfig(
    name: String,
    bg_color: String,
    text_color: String,
    accent_color: String,
    border_color: String,
    card_bg: String,
    font_family: String,
    layout_style: String,
    shadow_depth: String,
    border_radius: String,
    spacing_scale: String,
    custom_flourish: String,
  )
}

pub fn new(config: ThemeConfig) -> Theme {
  Theme(
    layout: fn(title, body) { layout(config, title, body) },
    post_view: post_view,
    archive_view: archive_view,
  )
}

fn layout(config: ThemeConfig, title: String, body: String) -> String {
  "<!DOCTYPE html>
<html lang=\"en\">
<head>
  <meta charset=\"UTF-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
  <title>" <> title <> " — " <> config.name <> "</title>
</head>
<body>
  <header>
    " <> navbar(config) <> "
  </header>
  <hr />
  <main>
    " <> body <> "
  </main>
  <hr />
  " <> footer(config) <> "
</body>
</html>"
}

fn navbar(_config: ThemeConfig) -> String {
  "<nav>
    <strong><a href=\"/\">GleamCMS</a></strong> |
    <a href=\"/\">Home</a> |
    <a href=\"/admin\">Studio</a> |
    <a href=\"/sites\">Sites</a> |
    <a href=\"/feed.xml\">RSS</a>
  </nav>"
}

fn footer(config: ThemeConfig) -> String {
  "<footer>
    <p><small>&copy; 2026 Sovereign Individual. Theme: " <> config.name <> ". Built with Pure Gleam (Zero CSS, Zero JS).</small></p>
  </footer>"
}

fn post_view(post: Post) -> String {
  case post.get_section_type(post) {
    "hero" -> render_hero_section(post)
    "features" -> render_features_section(post)
    "stats" -> render_stats_section(post)
    "cta" -> render_cta_section(post)
    _ -> render_content_section(post)
  }
}

fn render_hero_section(post: Post) -> String {
  let content = post.get_content(post) |> markdown.parse |> markdown.to_html
  "<header>
    <h1>" <> post.get_title(post) <> "</h1>
    <div>" <> content <> "</div>
  </header>"
}

fn render_features_section(post: Post) -> String {
  let content = post.get_content(post) |> markdown.parse |> markdown.to_html
  "<section>
    <h2>" <> post.get_title(post) <> "</h2>
    <div>" <> content <> "</div>
  </section>"
}

fn render_stats_section(post: Post) -> String {
  let content = post.get_content(post) |> markdown.parse |> markdown.to_html
  "<section>
    <h2>" <> post.get_title(post) <> "</h2>
    <div>" <> content <> "</div>
  </section>"
}

fn render_cta_section(post: Post) -> String {
  let content = post.get_content(post) |> markdown.parse |> markdown.to_html
  "<section>
    <h2>" <> post.get_title(post) <> "</h2>
    <div>" <> content <> "</div>
  </section>"
}

fn render_content_section(post: Post) -> String {
  let content = post.get_content(post) |> markdown.parse |> markdown.to_html
  "<article>
    <header>
      <h1>" <> post.get_title(post) <> "</h1>
    </header>
    <div>
      " <> content <> "
    </div>
  </article>"
}

fn archive_view(posts: List(Post)) -> String {
  let sorted_posts =
    list.sort(posts, fn(a, b) {
      string.compare(post.get_slug(a), post.get_slug(b))
    })

  let #(sections, regular) =
    list.partition(sorted_posts, fn(p) { post.get_section_type(p) != "content" })

  let section_html = list.map(sections, post_view) |> string.join("\n<hr />\n")

  let regular_links =
    list.map(regular, fn(p) {
      "<li><a href=\"/posts/"
      <> post.get_slug(p)
      <> ".html\">"
      <> post.get_title(p)
      <> "</a></li>"
    })
    |> string.join("\n")

  let archive_section = case regular {
    [] -> ""
    _ -> "<section>
            <h2>Latest Posts</h2>
            <ul>" <> regular_links <> "</ul>
          </section>"
  }

  section_html <> "\n<hr />\n" <> archive_section
}
