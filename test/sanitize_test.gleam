import gleam/string
import gleamcms/db/post
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

/// `<script>` blocks are removed together with their content, so neither the
/// tag nor the payload survives.
pub fn script_block_content_removed_test() {
  let out = post.sanitize_html("<script>alert(1)</script>")
  string.contains(out, "script") |> should.be_false
  string.contains(out, "alert") |> should.be_false
}

/// Dangerous block elements are removed case-insensitively, including content.
pub fn dangerous_blocks_removed_test() {
  let out =
    post.sanitize_html("<STYLE>.x{color:red}</STYLE><iframe>evil</iframe>")
  string.contains(out, "color:red") |> should.be_false
  string.contains(out, "evil") |> should.be_false
}

/// Inline event-handler attributes (on*) are stripped in every quote style:
/// double-quoted here.
pub fn event_handler_stripped_double_test() {
  let out = post.sanitize_html("<img src=\"x\" onerror=\"alert(1)\">")
  string.contains(out, "onerror") |> should.be_false
  string.contains(out, "src=\"x\"") |> should.be_true
}

/// …and single-quoted here.
pub fn event_handler_stripped_single_test() {
  let out = post.sanitize_html("<img src='x' onerror='alert(1)'>")
  string.contains(out, "onerror") |> should.be_false
  string.contains(out, "src='x'") |> should.be_true
}

/// …and unquoted here.
pub fn event_handler_stripped_unquoted_test() {
  let out = post.sanitize_html("<img src=x onload=alert(1)>")
  string.contains(out, "onload") |> should.be_false
  string.contains(out, "src=x") |> should.be_true
}

/// Dangerous URL schemes in href/src are neutralized (the whole attr goes).
pub fn javascript_href_neutralized_test() {
  let out = post.sanitize_html("<a href=\"javascript:alert(1)\">click</a>")
  string.contains(out, "javascript") |> should.be_false
  string.contains(out, "click") |> should.be_true
}

/// Other script-bearing URL forms are also removed.
pub fn dangerous_url_variants_neutralized_test() {
  let out =
    post.sanitize_html(
      "<img src='data:image/svg+xml,<svg onload=1>'><a href=vbscript:run>go</a>",
    )
  string.contains(out, "data:image/svg") |> should.be_false
  string.contains(out, "vbscript") |> should.be_false
  string.contains(out, "go") |> should.be_true
}

/// Obfuscated payloads that re-form a real tag after a single pass — e.g.
/// `<scr<script>ipt>` — are caught by the recursive stabilization.
pub fn obfuscated_script_defeated_test() {
  let out = post.sanitize_html("<scr<script>ipt>alert(1)</script>")
  string.contains(out, "script") |> should.be_false
  string.contains(out, "alert") |> should.be_false
}

/// Case-insensitive: uppercase / mixed-case dangerous tags are caught too.
pub fn uppercase_script_removed_test() {
  let out = post.sanitize_html("<SCRIPT>alert(1)</SCRIPT>")
  string.contains(out, "alert") |> should.be_false
}

/// Safe markup passes through untouched.
pub fn safe_markup_preserved_test() {
  post.sanitize_html("<p>hello <strong>world</strong></p>")
  |> should.equal("<p>hello <strong>world</strong></p>")
}
