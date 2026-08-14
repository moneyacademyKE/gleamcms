import gleamcms/content/markdown
import gleeunit/should

pub fn markdown_heading_and_paragraph_test() {
  let input = "# My Heading\n\nThis is a paragraph."
  let doc = markdown.parse(input)
  let html = markdown.to_html(doc)

  html |> should.equal("<h1>My Heading</h1>\n<p>This is a paragraph.</p>")
}

pub fn markdown_bold_italic_code_test() {
  let input = "Hello **world** and *everyone* with `code`."
  let doc = markdown.parse(input)
  let html = markdown.to_html(doc)

  html
  |> should.equal(
    "<p>Hello <strong>world</strong> and <em>everyone</em> with <code>code</code>.</p>",
  )
}

pub fn markdown_code_block_test() {
  let input = "```gleam\nfn main() { Nil }\n```"
  let doc = markdown.parse(input)
  let html = markdown.to_html(doc)

  html
  |> should.equal(
    "<pre><code class=\"language-gleam\">fn main() { Nil }</code></pre>",
  )
}

pub fn markdown_lists_test() {
  let input = "- Item 1\n- Item 2\n\n1. First\n2. Second"
  let doc = markdown.parse(input)
  let html = markdown.to_html(doc)

  html
  |> should.equal(
    "<ul><li>Item 1</li><li>Item 2</li></ul>\n<ol><li>First</li><li>Second</li></ol>",
  )
}

pub fn markdown_link_and_image_test() {
  let input =
    "[Gleam](https://gleam.run)\n\n![Logo](https://gleam.run/logo.png)"
  let doc = markdown.parse(input)
  let html = markdown.to_html(doc)

  html
  |> should.equal(
    "<p><a href=\"https://gleam.run\">Gleam</a></p>\n<p><img src=\"https://gleam.run/logo.png\" alt=\"Logo\" /></p>",
  )
}

pub fn markdown_escapes_xss_injection_test() {
  let input = "<script>alert('xss')</script>"
  let doc = markdown.parse(input)
  let html = markdown.to_html(doc)

  html
  |> should.equal("<p>&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;</p>")
}

pub fn markdown_neutralizes_javascript_urls_test() {
  let input = "[Click me](javascript:alert(1))"
  let doc = markdown.parse(input)
  let html = markdown.to_html(doc)

  html |> should.equal("<p><a href=\"#\">Click me</a></p>")
}
