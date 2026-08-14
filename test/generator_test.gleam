import aarondb
import gleamcms/builder/generator
import gleamcms/config
import gleamcms/db/post.{Published}
import gleamcms/db/schema
import gleeunit/should
import simplifile

pub fn generator_builds_atomic_site_output_test() {
  let db = aarondb.new()
  schema.init_schema(db)

  let cfg =
    config.Config(
      secret: "test-secret",
      admin_token: "test-token",
      output_dir: "test_gen_output",
      data_dir: "test_gen_data",
      port: 4000,
      cookie_max_age: 3600,
      import_legacy: False,
    )

  let p =
    post.new_post(
      "hello-world",
      "Hello World",
      "hello-world",
      "# Welcome to GleamCMS",
    )
    |> post.with_status(Published)

  post.save_post(db, p) |> should.be_ok

  let report = generator.build(db, "Default Dark", cfg)
  report.errors |> should.equal([])
  report.pages_written |> should.equal(2)

  let index_exists =
    simplifile.is_file("test_gen_output/default-dark/index.html")
  index_exists |> should.equal(Ok(True))

  let post_exists =
    simplifile.is_file("test_gen_output/default-dark/hello-world.html")
  post_exists |> should.equal(Ok(True))

  let feed_exists = simplifile.is_file("test_gen_output/default-dark/feed.xml")
  feed_exists |> should.equal(Ok(True))

  // Clean up
  let _ = simplifile.delete("test_gen_output")
  Nil
}
