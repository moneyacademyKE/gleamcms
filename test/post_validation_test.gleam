import aarondb
import gleamcms/db/post
import gleamcms/db/schema
import gleeunit/should

/// A well-formed slug (and title) passes validation.
pub fn valid_slug_passes_test() {
  post.new_post("1", "Hello World", "hello-world", "body")
  |> post.validate_post
  |> should.be_ok
}

/// A malformed slug is rejected before it can reach the database. This is the
/// guarantee that save_post relies on (it validates before constructing facts).
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
