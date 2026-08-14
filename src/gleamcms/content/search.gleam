import aarondb
import aarondb/fact
import aarondb/index/bm25.{type BM25Index, type SearchResult}
import gleam/list
import gleam/string
import gleamcms/db/post.{type Post}

pub type SearchMatch {
  SearchMatch(post: Post, score: Float, snippet: String)
}

pub fn build_content_index(posts: List(Post)) -> BM25Index {
  list.fold(posts, bm25.empty("cms.post/content"), fn(idx, p) {
    let eid = fact.ref(fact.phash2(post.get_slug(p)))
    let combined_text = post.get_title(p) <> " " <> post.get_content(p)
    bm25.add(idx, eid, combined_text)
  })
}

pub fn search(posts: List(Post), query: String) -> List(SearchMatch) {
  let index = build_content_index(posts)
  // Standard BM25 parameters: k1 = 1.5, b = 0.75, top 50 matches
  let results: List(SearchResult) = bm25.search(index, query, 1.5, 0.75, 50)

  list.filter_map(results, fn(r) {
    case
      list.find(posts, fn(p) {
        fact.ref(fact.phash2(post.get_slug(p))) == r.entity
      })
    {
      Ok(p) -> {
        let snippet = extract_snippet(post.get_content(p), query, 120)
        Ok(SearchMatch(post: p, score: r.score, snippet: snippet))
      }
      Error(_) -> Error(Nil)
    }
  })
}

pub fn extract_snippet(text: String, query: String, max_len: Int) -> String {
  let clean_text = string.replace(text, "\n", " ")
  let clean_query = string.trim(string.lowercase(query))
  let lower_text = string.lowercase(clean_text)

  case string.contains(lower_text, clean_query) {
    False -> string.slice(clean_text, 0, max_len)
    True -> {
      case string.split_once(lower_text, clean_query) {
        Ok(#(before, _)) -> {
          let before_len = string.length(before)
          let start_idx = case before_len > 30 {
            True -> before_len - 30
            False -> 0
          }
          let prefix = case start_idx > 0 {
            True -> "..."
            False -> ""
          }
          let extracted = string.slice(clean_text, start_idx, max_len)
          prefix <> extracted <> "..."
        }
        Error(_) -> string.slice(clean_text, 0, max_len)
      }
    }
  }
}

pub fn search_published_posts(
  db: aarondb.Db,
  query: String,
) -> List(SearchMatch) {
  let posts = post.get_all_published(db)
  search(posts, query)
}
