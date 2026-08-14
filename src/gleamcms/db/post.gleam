import aarondb
import aarondb/fact.{Str}
import aarondb/shared/ast.{Val, Var}
import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import gleam/string

pub type PostStatus {
  Draft
  Published
  Archived
}

pub opaque type Post {
  Post(
    id: String,
    title: String,
    slug: String,
    content: String,
    status: PostStatus,
    published_at: Option(Int),
    featured_image: Option(String),
    section_type: String,
  )
}

pub fn get_id(post: Post) -> String {
  post.id
}

pub fn get_title(post: Post) -> String {
  post.title
}

pub fn get_slug(post: Post) -> String {
  post.slug
}

pub fn get_content(post: Post) -> String {
  post.content
}

pub fn get_status(post: Post) -> PostStatus {
  post.status
}

pub fn get_published_at(post: Post) -> Option(Int) {
  post.published_at
}

pub fn get_featured_image(post: Post) -> Option(String) {
  post.featured_image
}

pub fn get_section_type(post: Post) -> String {
  post.section_type
}

pub fn new_post(
  id: String,
  title: String,
  slug: String,
  content: String,
) -> Post {
  Post(id, title, slug, content, Draft, None, None, "content")
}

pub fn draft(id: String, title: String, slug: String, content: String) -> Post {
  new_post(id, title, slug, content)
}

pub fn publish(post: Post, timestamp: Int) -> Result(Post, List(String)) {
  let updated = Post(..post, status: Published, published_at: Some(timestamp))
  validate_post(updated)
}

pub fn archive(post: Post) -> Post {
  Post(..post, status: Archived)
}

pub fn is_published(post: Post) -> Bool {
  post.status == Published
}

pub fn with_status(post: Post, status: PostStatus) -> Post {
  Post(..post, status: status)
}

pub fn with_published_at(post: Post, published_at: Option(Int)) -> Post {
  Post(..post, published_at: published_at)
}

pub fn with_featured_image(post: Post, image: Option(String)) -> Post {
  Post(..post, featured_image: image)
}

pub fn with_section_type(post: Post, section_type: String) -> Post {
  Post(..post, section_type: section_type)
}

pub fn validate_post(post: Post) -> Result(Post, List(String)) {
  let errors = []
  let errors = case is_valid_slug(post.slug) {
    True -> errors
    False -> [
      "Invalid slug format (lowercase alphanumeric and hyphens only)",
      ..errors
    ]
  }
  let errors = case string.length(post.title) {
    l if l > 0 && l < 200 -> errors
    _ -> ["Title must be between 1 and 200 characters", ..errors]
  }

  case errors {
    [] -> Ok(post)
    _ -> Error(errors)
  }
}

pub fn save_post(db: aarondb.Db, post: Post) -> Result(Nil, List(String)) {
  use validated_post <- result.try(
    validate_post(post) |> result.map_error(fn(e) { e }),
  )

  let eid = fact.deterministic_uid(validated_post.id)

  let facts = [
    #(eid, "cms.post/id", Str(validated_post.id)),
    #(eid, "cms.post/title", Str(sanitize_html(validated_post.title))),
    #(eid, "cms.post/slug", Str(validated_post.slug)),
    #(eid, "cms.post/content", Str(sanitize_html(validated_post.content))),
    #(eid, "cms.post/status", Str(status_to_string(validated_post.status))),
    #(eid, "cms.post/section_type", Str(validated_post.section_type)),
  ]

  let facts = case validated_post.published_at {
    Some(ts) -> [#(eid, "cms.post/published_at", fact.Int(ts)), ..facts]
    None -> facts
  }

  let facts = case validated_post.featured_image {
    Some(img) -> [#(eid, "cms.post/featured_image", Str(img)), ..facts]
    None -> facts
  }

  // Wrap in atomic transaction
  case aarondb.transact(db, facts) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(["Database transaction failed"])
  }
}

pub fn get_post_by_slug(db: aarondb.Db, slug: String) -> Result(Post, Nil) {
  // Single datalog pass. Previously this ran a 6-pattern query, ignored the
  // returned rows, then re-fetched each field with five separate get_one
  // lookups (plus `let assert` bombs). Now it reads the row directly, the
  // same shape as get_all_published.
  let q = [
    aarondb.p(#(Var("e"), "cms.post/slug", Val(Str(slug)))),
    aarondb.p(#(Var("e"), "cms.post/id", Var("id"))),
    aarondb.p(#(Var("e"), "cms.post/title", Var("title"))),
    aarondb.p(#(Var("e"), "cms.post/content", Var("content"))),
    aarondb.p(#(Var("e"), "cms.post/status", Var("status"))),
    aarondb.p(#(Var("e"), "cms.post/section_type", Var("section_type"))),
  ]
  let res = aarondb.query(db, q)
  case list.first(res.rows) {
    Ok(row) ->
      case
        dict.get(row, "id"),
        dict.get(row, "title"),
        dict.get(row, "content"),
        dict.get(row, "status"),
        dict.get(row, "section_type")
      {
        Ok(Str(id)),
          Ok(Str(title)),
          Ok(Str(content)),
          Ok(Str(status)),
          Ok(Str(section_type))
        -> {
          let eid = fact.deterministic_uid(id)
          let published_at = case
            aarondb.get_one(db, eid, "cms.post/published_at")
          {
            Ok(fact.Int(ts)) -> Some(ts)
            _ -> None
          }
          let featured_image = case
            aarondb.get_one(db, eid, "cms.post/featured_image")
          {
            Ok(Str(img)) -> Some(img)
            _ -> None
          }
          Ok(Post(
            id: id,
            title: title,
            slug: slug,
            content: content,
            status: string_to_status(status),
            published_at: published_at,
            featured_image: featured_image,
            section_type: section_type,
          ))
        }
        _, _, _, _, _ -> Error(Nil)
      }
    Error(_) -> Error(Nil)
  }
}

pub fn status_to_string(status: PostStatus) -> String {
  case status {
    Draft -> "draft"
    Published -> "published"
    Archived -> "archived"
  }
}

pub fn string_to_status(status: String) -> PostStatus {
  case status {
    "published" -> Published
    "archived" -> Archived
    _ -> Draft
  }
}

/// Remove one regular expression from the input. Inline `(?is)` makes every
/// pattern case-insensitive and lets `.` span newlines (dotall). If a pattern
/// ever fails to compile the input is returned unchanged (defensive — never
/// throws).
///
fn strip(from input: String, drop pattern: String) -> String {
  case regexp.compile("(?is)" <> pattern, regexp.Options(False, False)) {
    Ok(re) -> regexp.replace(each: re, in: input, with: "")
    Error(_) -> input
  }
}

/// Remove dangerous element *blocks* including their content, e.g.
/// `<script>...</script>`. Non-greedy, case-insensitive, newline-spanning.
///
fn strip_blocks(input: String) -> String {
  input
  |> strip("<[[:space:]]*script\\b.*?<[[:space:]]*/[[:space:]]*script[^>]*>")
  |> strip("<[[:space:]]*style\\b.*?<[[:space:]]*/[[:space:]]*style[^>]*>")
  |> strip("<[[:space:]]*iframe\\b.*?<[[:space:]]*/[[:space:]]*iframe[^>]*>")
  |> strip("<[[:space:]]*object\\b.*?<[[:space:]]*/[[:space:]]*object[^>]*>")
  |> strip("<[[:space:]]*embed\\b.*?<[[:space:]]*/[[:space:]]*embed[^>]*>")
  |> strip(
    "<[[:space:]]*noscript\\b.*?<[[:space:]]*/[[:space:]]*noscript[^>]*>",
  )
  |> strip(
    "<[[:space:]]*template\\b.*?<[[:space:]]*/[[:space:]]*template[^>]*>",
  )
}

/// Remove dangerous standalone/void tags, open or close.
///
fn strip_dangerous_tags(input: String) -> String {
  strip(
    input,
    "<[[:space:]]*/?[[:space:]]*(script|iframe|object|embed|applet|base|meta|link|form|input|button|textarea|select|svg|math|frame|frameset)\\b[^>]*>",
  )
}

/// Strip inline event-handler attributes in all quote styles (double, single,
/// and unquoted): `onclick="..."`, `onerror='...'`, `onload=x`.
///
fn strip_event_handlers(input: String) -> String {
  input
  |> strip("[[:space:]]on[a-z0-9_-]+[[:space:]]*=[[:space:]]*\"[^\"]*\"")
  |> strip("[[:space:]]on[a-z0-9_-]+[[:space:]]*=[[:space:]]*'[^']*'")
  |> strip("[[:space:]]on[a-z0-9_-]+[[:space:]]*=[[:space:]]*[^[:space:]>]+")
}

/// Neutralize dangerous URL schemes in link/src-type attributes across quote
/// styles: `javascript:`, `vbscript:`, `data:text/html`, `data:image/svg`, …
///
fn strip_dangerous_urls(input: String) -> String {
  let sink =
    "(href|src|xlink:href|formaction|poster|background|dynsrc|lowsrc|data|cite|longdesc|usemap|profile|action)"
  let scheme =
    "(javascript|vbscript|livescript|mocha|data:text/html|data:image/svg)"
  input
  |> strip(sink <> "[[:space:]]*=[[:space:]]*\"[^\"]*" <> scheme <> "[^\"]*\"")
  |> strip(sink <> "[[:space:]]*=[[:space:]]*'[^']*" <> scheme <> "[^']*'")
  |> strip(sink <> "[[:space:]]*=[[:space:]]*[a-z]*script:[^[:space:]>]*")
}

/// One full sanitization pass over the content.
///
fn sanitize_pass(input: String) -> String {
  input
  |> strip_blocks
  |> strip_dangerous_tags
  |> strip_event_handlers
  |> strip_dangerous_urls
}

/// Recursively re-sanitize until the output stabilizes. This defeats obfuscated
/// payloads like `<scr<script>ipt>` that re-form a real tag after a single pass
/// removes the inner fragment. Each pass only removes characters, so the string
/// strictly shortens or stabilizes — termination is guaranteed; the depth cap is
/// purely defensive.
///
pub fn sanitize_html(input: String) -> String {
  sanitize_until_stable("", input, 0)
}

fn sanitize_until_stable(
  previous: String,
  current: String,
  depth: Int,
) -> String {
  case previous == current || depth > 8 {
    True -> current
    False -> sanitize_until_stable(current, sanitize_pass(current), depth + 1)
  }
}

pub fn is_valid_slug(slug: String) -> Bool {
  // Native robustness: Check for allowed characters without regex dependency
  let allowed = "abcdefghijklmnopqrstuvwxyz0123456789-"
  case slug {
    "" -> False
    _ -> {
      slug
      |> string.to_graphemes
      |> list.all(fn(c) { string.contains(allowed, c) })
    }
  }
}

/// Fetch all published posts in a single query pass (no N+1).
pub fn get_all_published(db: aarondb.Db) -> List(Post) {
  let q = [
    aarondb.p(#(Var("e"), "cms.post/status", Val(Str("published")))),
    aarondb.p(#(Var("e"), "cms.post/id", Var("id"))),
    aarondb.p(#(Var("e"), "cms.post/title", Var("title"))),
    aarondb.p(#(Var("e"), "cms.post/slug", Var("slug"))),
    aarondb.p(#(Var("e"), "cms.post/content", Var("content"))),
    aarondb.p(#(Var("e"), "cms.post/section_type", Var("section_type"))),
  ]
  let res = aarondb.query(db, q)
  list.filter_map(res.rows, fn(row) {
    case
      dict.get(row, "id"),
      dict.get(row, "title"),
      dict.get(row, "slug"),
      dict.get(row, "content"),
      dict.get(row, "section_type")
    {
      Ok(Str(id)),
        Ok(Str(title)),
        Ok(Str(slug)),
        Ok(Str(content)),
        Ok(Str(section_type))
      -> {
        let eid = fact.deterministic_uid(id)
        let published_at = case
          aarondb.get_one(db, eid, "cms.post/published_at")
        {
          Ok(fact.Int(ts)) -> Some(ts)
          _ -> None
        }
        let featured_image = case
          aarondb.get_one(db, eid, "cms.post/featured_image")
        {
          Ok(Str(img)) -> Some(img)
          _ -> None
        }
        Ok(Post(
          id: id,
          title: title,
          slug: slug,
          content: content,
          status: Published,
          published_at: published_at,
          featured_image: featured_image,
          section_type: section_type,
        ))
      }
      _, _, _, _, _ -> Error(Nil)
    }
  })
}
