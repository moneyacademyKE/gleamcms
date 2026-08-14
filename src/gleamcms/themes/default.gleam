import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleamcms/content/markdown
import gleamcms/db/post.{type Post}
import gleamcms/theme.{type Theme, Theme}

pub fn new() -> Theme {
  Theme(layout: layout, post_view: post_view, archive_view: archive_view)
}

pub fn layout(title: String, body: String) -> String {
  "<!DOCTYPE html>
<html lang=\"en\">
<head>
  <meta charset=\"UTF-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
  <title>" <> title <> " — GleamCMS</title>
</head>
<body>
  <header>
    " <> navbar() <> "
  </header>
  <hr />
  <main>
    " <> body <> "
  </main>
  <hr />
  " <> footer() <> "
</body>
</html>"
}

pub fn navbar() -> String {
  "<nav>
    <strong><a href=\"/\">GleamCMS</a></strong> |
    <a href=\"/\">Home</a> |
    <a href=\"/admin\">Studio</a> |
    <a href=\"/sites\">Sites</a> |
    <a href=\"/feed.xml\">RSS Feed</a>
  </nav>"
}

pub fn footer() -> String {
  "<footer>
    <p><small>&copy; 2026 Sovereign Individual. Built with Pure Gleam on the BEAM. Zero CSS, Zero JavaScript.</small></p>
  </footer>"
}

pub fn post_view(post: Post) -> String {
  let date_str = case post.get_published_at(post) {
    Some(ts) -> "Published on " <> int_to_string(ts)
    None -> "Draft"
  }

  let rendered_content =
    post.get_content(post)
    |> markdown.parse
    |> markdown.to_html

  "<article>
    <header>
      <h1>" <> post.get_title(post) <> "</h1>
      <p><small>" <> date_str <> "</small></p>
    </header>
    <section>
      " <> rendered_content <> "
    </section>
  </article>"
}

pub fn archive_view(posts: List(Post)) -> String {
  let list_items =
    list.map(posts, fn(p) {
      "<li><a href=\"/posts/"
      <> post.get_slug(p)
      <> ".html\">"
      <> post.get_title(p)
      <> "</a></li>"
    })
    |> list.fold("", fn(acc, item) { acc <> item })

  "<section>
     <h2>Post Archive</h2>
     <ul>" <> list_items <> "</ul>
   </section>"
}

fn int_to_string(i: Int) -> String {
  int.to_string(i)
}
