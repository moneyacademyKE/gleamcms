import gleam/list
import gleamcms/content/search
import gleamcms/db/post.{Published}
import gleeunit/should

pub fn bm25_search_ranking_test() {
  let p1 =
    post.new_post(
      "1",
      "Functional Architecture in Gleam",
      "functional-architecture",
      "Erlang and BEAM provide sovereign fault tolerance and immutable state.",
    )
    |> post.with_status(Published)

  let p2 =
    post.new_post(
      "2",
      "PostgreSQL and Web Development",
      "postgres-web",
      "Traditional database setups require mutable row mutations.",
    )
    |> post.with_status(Published)

  let p3 =
    post.new_post(
      "3",
      "Sovereign Datalog Foundations",
      "sovereign-datalog",
      "Datalog fact stores on the BEAM offer temporal audit history.",
    )
    |> post.with_status(Published)

  let posts = [p1, p2, p3]

  let results = search.search(posts, "BEAM")
  list.length(results) |> should.equal(2)

  let assert Ok(first) = list.first(results)
  {
    post.get_slug(first.post) == "functional-architecture"
    || post.get_slug(first.post) == "sovereign-datalog"
  }
  |> should.be_true

  // Non-matching term returns empty
  let empty_results = search.search(posts, "Kubernetes")
  list.length(empty_results) |> should.equal(0)
}
