import aarondb
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleamcms/builder/theme as theme_provider
import gleamcms/config
import gleamcms/db/post.{type Post, Published}
import gleamcms/theme.{type Theme}
import gleamcms/themes/library
import simplifile

pub fn seed_showcase_posts(db: aarondb.Db) -> Result(Nil, List(String)) {
  let configs = library.get_configs()
  let results =
    list.index_map(configs, fn(config, i) {
      let id = "showcase-" <> int.to_string(i + 1)
      let title = "Showcase: " <> config.name
      let slug = "showcase-" <> int.to_string(i + 1)
      let content =
        "# Welcome to "
        <> config.name
        <> "\n\nThis post demonstrates the "
        <> config.name
        <> " theme in GleamCMS."
      let p =
        post.new_post(id, title, slug, content)
        |> post.with_status(Published)
      post.save_post(db, p)
    })

  case
    list.filter_map(results, fn(r) {
      case r {
        Error(e) -> Ok(e)
        Ok(_) -> Error(Nil)
      }
    })
  {
    [] -> Ok(Nil)
    errors -> Error(list.flatten(errors))
  }
}

pub type BuildReport {
  BuildReport(
    theme_name: String,
    pages_written: Int,
    output_dir: String,
    errors: List(String),
  )
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Build one themed site → gleamcms_output/<theme-slug>/
///
/// Thin wrapper over `do_build` (the single renderer implementation) that
/// supplies every published post. Previously `build/2` and `do_build/3` were
/// two near-identical copies of the same write logic.
pub fn build(
  db: aarondb.Db,
  theme_name: String,
  cfg: config.Config,
) -> BuildReport {
  do_build(cfg, theme_name, post.get_all_published(db))
}

/// Build ALL 50 themes → one report per theme.
pub fn build_all(db: aarondb.Db, cfg: config.Config) -> List(BuildReport) {
  library.get_configs()
  |> list.map(fn(c) { build(db, c.name, cfg) })
}

/// Specialized build: 50 sites, each with exactly ONE unique post.
pub fn build_showcase(db: aarondb.Db, cfg: config.Config) -> List(BuildReport) {
  let root = config.output_dir(cfg)
  let _ = simplifile.delete(root)
  let _ = simplifile.create_directory_all(root)

  let configs = library.get_configs()
  let posts = post.get_all_published(db)

  // Filter for posts created by seed_showcase_posts
  let showcase_posts =
    list.filter(posts, fn(p) {
      string.starts_with(post.get_slug(p), "showcase-")
    })

  // Each theme i is paired with showcase post (i mod count) — a true rotation
  // across the available posts, instead of the old drop/fallback that biased
  // every out-of-range theme toward post 0.
  let count = list.length(showcase_posts)

  list.index_map(configs, fn(config, i) {
    let theme_posts = case count {
      0 -> []
      _ -> {
        let idx = int.modulo(i, count) |> result.unwrap(0)
        case list.drop(showcase_posts, idx) |> list.first {
          Ok(p) -> [p]
          Error(_) -> []
        }
      }
    }
    do_build(cfg, config.name, theme_posts)
  })
}

fn do_build(
  cfg: config.Config,
  theme_name: String,
  theme_posts: List(Post),
) -> BuildReport {
  let slug = slugify(theme_name)
  let root = config.output_dir(cfg)
  let _ = simplifile.create_directory_all(root)
  let output_dir = root <> "/" <> slug
  let staging_dir = output_dir <> ".staging"

  let _ = simplifile.delete(staging_dir)
  let staging_created = simplifile.create_directory_all(staging_dir)

  case staging_created {
    Error(e) ->
      BuildReport(
        theme_name: theme_name,
        pages_written: 0,
        output_dir: output_dir,
        errors: ["Failed to create staging directory: " <> string.inspect(e)],
      )
    Ok(_) -> {
      let t = theme_provider.get_by_name(theme_name)

      let post_results =
        list.map(theme_posts, fn(p) {
          let path = staging_dir <> "/" <> post.get_slug(p) <> ".html"
          case simplifile.write(path, render_post(p, t)) {
            Ok(_) -> Ok(path)
            Error(e) -> Error("Failed " <> path <> ": " <> string.inspect(e))
          }
        })

      let post_errors =
        list.filter_map(post_results, fn(r) {
          case r {
            Error(e) -> Ok(e)
            Ok(_) -> Error(Nil)
          }
        })

      let index_res =
        simplifile.write(
          staging_dir <> "/index.html",
          render_index(theme_posts, t),
        )
      let rss_res =
        simplifile.write(staging_dir <> "/feed.xml", render_rss(theme_posts))

      let aux_errors = []
      let aux_errors = case index_res {
        Ok(_) -> aux_errors
        Error(e) -> ["Failed index.html: " <> string.inspect(e), ..aux_errors]
      }
      let aux_errors = case rss_res {
        Ok(_) -> aux_errors
        Error(e) -> ["Failed feed.xml: " <> string.inspect(e), ..aux_errors]
      }

      let all_errors = list.append(post_errors, aux_errors)

      case all_errors {
        [] -> {
          let _ = simplifile.delete(output_dir)
          case simplifile.rename(at: staging_dir, to: output_dir) {
            Ok(_) ->
              BuildReport(
                theme_name: theme_name,
                pages_written: list.length(theme_posts) + 1,
                output_dir: output_dir,
                errors: [],
              )
            Error(e) -> {
              let _ = simplifile.delete(staging_dir)
              BuildReport(
                theme_name: theme_name,
                pages_written: 0,
                output_dir: output_dir,
                errors: ["Failed atomic swap: " <> string.inspect(e)],
              )
            }
          }
        }
        errors -> {
          let _ = simplifile.delete(staging_dir)
          BuildReport(
            theme_name: theme_name,
            pages_written: 0,
            output_dir: output_dir,
            errors: errors,
          )
        }
      }
    }
  }
}

/// List theme slugs that have already been generated on disk.
pub fn list_generated(cfg: config.Config) -> List(String) {
  case simplifile.read_directory(config.output_dir(cfg)) {
    Ok(entries) ->
      entries
      |> list.filter(fn(e) { e != "." && e != ".." && !string.contains(e, ".") })
    Error(_) -> []
  }
}

// ---------------------------------------------------------------------------
// Renderers
// ---------------------------------------------------------------------------

fn render_post(p: Post, t: Theme) -> String {
  let content = { t.post_view }(p)
  { t.layout }(post.get_title(p), content)
}

fn render_index(posts: List(Post), t: Theme) -> String {
  let content = { t.archive_view }(posts)
  { t.layout }("Archive", content)
}

fn render_rss(posts: List(Post)) -> String {
  let items =
    list.map(posts, fn(p) {
      "<item><title>"
      <> post.get_title(p)
      <> "</title>"
      <> "<link>/posts/"
      <> post.get_slug(p)
      <> "</link></item>"
    })
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
  <> "<rss version=\"2.0\"><channel><title>GleamCMS</title><link>/</link>"
  <> string.join(items, "\n")
  <> "</channel></rss>"
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn slugify(name: String) -> String {
  name
  |> string.lowercase
  |> string.replace(" ", "-")
}
