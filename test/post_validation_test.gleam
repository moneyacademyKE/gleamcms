import aarondb
import gleam/option.{Some}
import gleamcms/db/post.{Published}
import gleamcms/db/schema
import gleeunit/should

/// A well-formed slug (and title) passes validation.
pub fn valid_slug_passes_test() {
  post.new_post("1", "Hello World", "hello-world", "body")
  |> post.validate_post
  |> should.be_ok
}

/// A malformed slug is rejected before it can reach the database.
pub fn invalid_slug_rejected_test() {
  post.new_post("1", "Hello", "Bad Slug!", "body")
  |> post.validate_post
  |> should.be_error
}

/// The save boundary returns the validation error and leaves no post behind.
pub fn invalid_slug_rejected_before_persistence_test() {
  let db = aarondb.new()
  schema.init_schema(db)

  let errors =
    post.new_post("1", "Hello", "Bad Slug!", "body")
    |> post.save_post(db, _)
    |> should.be_error

  errors
  |> should.equal([
    "Invalid slug format (lowercase alphanumeric and hyphens only)",
  ])

  post.get_post_by_slug(db, "Bad Slug!")
  |> should.be_error
}

/// Uppercase letters are not allowed in slugs.
pub fn uppercase_slug_rejected_test() {
  post.new_post("1", "Hello", "HelloWorld", "body")
  |> post.validate_post
  |> should.be_error
}

/// An empty title is rejected.
pub fn empty_title_rejected_test() {
  post.new_post("1", "", "ok-slug", "body")
  |> post.validate_post
  |> should.be_error
}

/// Optional fields like published_at and featured_image persist and query round-trip.
pub fn optional_attributes_round_trip_test() {
  let db = aarondb.new()
  schema.init_schema(db)

  let p =
    post.new_post("post-1", "Featured Post", "featured-post", "Content")
    |> post.with_status(Published)
    |> post.with_published_at(Some(1_700_000_000))
    |> post.with_featured_image(Some("https://example.com/image.png"))

  post.save_post(db, p) |> should.be_ok

  let assert Ok(fetched) = post.get_post_by_slug(db, "featured-post")
  post.get_published_at(fetched) |> should.equal(Some(1_700_000_000))
  post.get_featured_image(fetched)
  |> should.equal(Some("https://example.com/image.png"))

  let all = post.get_all_published(db)
  let assert Ok(first) = case all {
    [head, ..] -> Ok(head)
    _ -> Error(Nil)
  }
  post.get_published_at(first) |> should.equal(Some(1_700_000_000))
  post.get_featured_image(first)
  |> should.equal(Some("https://example.com/image.png"))
}

pub fn post_type_state_lifecycle_test() {
  let draft_post = post.draft("10", "Draft Title", "draft-slug", "Draft body")
  post.is_published(draft_post) |> should.be_false

  let assert Ok(pub_post) = post.publish(draft_post, 1_700_000_000)
  post.is_published(pub_post) |> should.be_true
  post.get_published_at(pub_post) |> should.equal(Some(1_700_000_000))

  let archived_post = post.archive(pub_post)
  post.is_published(archived_post) |> should.be_false

  // Publishing an invalid post returns error
  let invalid_draft = post.draft("11", "", "bad slug!", "body")
  post.publish(invalid_draft, 1_700_000_000) |> should.be_error
}
