import aarondb
import aarondb/fact
import aarondb/shared/ast.{Var}
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/uri
import gleamcms/ai/designer
import gleamcms/builder/generator
import gleamcms/builder/storage
import gleamcms/config
import gleamcms/content/search
import gleamcms/db/post.{Published}
import gleamcms/runtime/worker
import logging
import wisp.{type Request, type Response}

pub type PublishRequest {
  PublishRequest(title: String, slug: String, content: String)
}

pub type SyncFact {
  SyncFact(eid: String, attr: String, val: String)
}

pub type SaveRequest {
  SaveRequest(title: String, slug: String, content: String, status: String)
}

pub fn sync_fact_decoder() {
  use eid <- decode.field("eid", decode.string)
  use attr <- decode.field("attr", decode.string)
  use val <- decode.field("val", decode.string)
  decode.success(SyncFact(eid:, attr:, val:))
}

pub fn publish_request_decoder() {
  use title <- decode.field("title", decode.string)
  use slug <- decode.field("slug", decode.string)
  use content <- decode.field("content", decode.string)
  decode.success(PublishRequest(title:, slug:, content:))
}

pub fn save_request_decoder() {
  use title <- decode.field("title", decode.string)
  use slug <- decode.field("slug", decode.string)
  use content <- decode.field("content", decode.string)
  use status <- decode.field("status", decode.string)
  decode.success(SaveRequest(title:, slug:, content:, status:))
}

pub fn handle_health(db: aarondb.Db) -> Response {
  let q = [aarondb.p(#(Var("_"), "cms.post/id", Var("_")))]
  case aarondb.query(db, q) {
    _ -> {
      wisp.ok()
      |> wisp.json_body("{\"status\": \"healthy\", \"engine\": \"v2.1.0\"}")
    }
  }
}

pub fn serve_stats(_req: Request, db: aarondb.Db) -> Response {
  let q = [aarondb.p(#(Var("e"), "cms.post/id", Var("id")))]
  let res = aarondb.query(db, q)
  let count = list.length(res.rows)

  wisp.ok()
  |> wisp.html_body(
    "<h1>CMS Stats</h1><p>Total Posts: " <> int.to_string(count) <> "</p>",
  )
}

pub fn handle_save(req: Request, db: aarondb.Db) -> Response {
  case req.method {
    http.Post -> {
      use body <- wisp.require_string_body(req)
      case json.parse(body, save_request_decoder()) {
        Ok(r) -> {
          let p =
            post.new_post(r.slug, r.title, r.slug, r.content)
            |> post.with_status(post.string_to_status(r.status))
          case post.save_post(db, p) {
            Ok(_) -> {
              logging.log(logging.Info, "Saved post: " <> r.slug)
              case post.is_published(p) {
                True -> worker.async_dispatch_post_published([], p)
                False -> Nil
              }
              wisp.ok()
              |> wisp.json_body("{\"status\": \"saved\"}")
            }
            Error(errors) -> {
              let msg = list.first(errors) |> result.unwrap("")
              wisp.bad_request("Validation failed: " <> msg)
            }
          }
        }
        Error(_) -> {
          case uri.parse_query(body) {
            Ok(pairs) -> {
              let title = list.key_find(pairs, "title") |> result.unwrap("")
              let slug = list.key_find(pairs, "slug") |> result.unwrap("")
              let content = list.key_find(pairs, "content") |> result.unwrap("")
              let status =
                list.key_find(pairs, "status") |> result.unwrap("published")
              let section_type =
                list.key_find(pairs, "section_type")
                |> result.unwrap("content")

              let p =
                post.new_post(slug, title, slug, content)
                |> post.with_status(post.string_to_status(status))
                |> post.with_section_type(section_type)

              case post.save_post(db, p) {
                Ok(_) -> {
                  logging.log(logging.Info, "Saved form post: " <> slug)
                  case post.is_published(p) {
                    True -> worker.async_dispatch_post_published([], p)
                    False -> Nil
                  }
                  wisp.redirect(to: "/admin")
                }
                Error(errors) -> {
                  let msg = list.first(errors) |> result.unwrap("")
                  wisp.bad_request("Validation failed: " <> msg)
                }
              }
            }
            Error(_) -> wisp.bad_request("Invalid request format")
          }
        }
      }
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}

pub fn handle_publish(req: Request, db: aarondb.Db) -> Response {
  case req.method {
    http.Post -> {
      use body <- wisp.require_string_body(req)
      case json.parse(body, publish_request_decoder()) {
        Ok(pub_req) -> {
          let p =
            post.new_post(
              pub_req.slug,
              pub_req.title,
              pub_req.slug,
              pub_req.content,
            )
            |> post.with_status(Published)

          case post.save_post(db, p) {
            Ok(_) -> {
              logging.log(logging.Info, "Published post: " <> pub_req.slug)
              worker.async_dispatch_post_published([], p)
              wisp.ok()
              |> wisp.json_body("{\"status\": \"ok\"}")
            }
            Error(errors) -> {
              logging.log(
                logging.Warning,
                "Publication failed: " <> pub_req.slug,
              )
              let error_msg = list.first(errors) |> result.unwrap("")
              wisp.bad_request("Validation failed: " <> error_msg)
            }
          }
        }
        Error(_) -> wisp.bad_request("Invalid JSON")
      }
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}

pub fn handle_generate(
  req: Request,
  db: aarondb.Db,
  cfg: config.Config,
) -> Response {
  case req.method {
    http.Post -> {
      use body <- wisp.require_string_body(req)
      let is_form = case uri.parse_query(body) {
        Ok(pairs) -> list.key_find(pairs, "theme")
        Error(_) -> Error(Nil)
      }

      let theme_param = case is_form {
        Ok(t) -> t
        Error(_) ->
          wisp.get_query(req)
          |> list.key_find("theme")
          |> result.unwrap("Default Dark")
      }

      logging.log(logging.Info, "Generate site: theme=" <> theme_param)

      let reports = case theme_param {
        "all" -> generator.build_all(db, cfg)
        "showcase" -> {
          let _ = generator.seed_showcase_posts(db)
          generator.build_showcase(db, cfg)
        }
        name -> [generator.build(db, name, cfg)]
      }

      let total_pages =
        list.fold(reports, 0, fn(acc, r) { acc + r.pages_written })
      let total_errors =
        list.fold(reports, 0, fn(acc, r) { acc + list.length(r.errors) })
      let sites_built = list.length(reports)

      logging.log(
        logging.Info,
        "Build complete: "
          <> int.to_string(total_pages)
          <> " pages across "
          <> int.to_string(sites_built)
          <> " sites",
      )

      case is_form {
        Ok(_) -> wisp.redirect(to: "/sites")
        Error(_) -> {
          let resp_body =
            "{\"status\": \"ok\", \"sites\": "
            <> int.to_string(sites_built)
            <> ", \"pages\": "
            <> int.to_string(total_pages)
            <> ", \"errors\": "
            <> int.to_string(total_errors)
            <> "}"

          wisp.ok()
          |> wisp.json_body(resp_body)
        }
      }
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}

pub fn handle_ai_design(req: Request, db: aarondb.Db) -> Response {
  case req.method {
    http.Post -> {
      use body <- wisp.require_string_body(req)
      let prompt = case
        json.parse(from: body, using: {
          use p <- decode.field("prompt", decode.string)
          decode.success(p)
        })
      {
        Ok(p) -> p
        Error(_) -> ""
      }

      case prompt {
        "" -> wisp.bad_request("Missing prompt")
        _ -> {
          case designer.design_theme(prompt) {
            Ok(theme_cfg) -> {
              let _ =
                list.index_map(theme_cfg.sections, fn(sec, i) {
                  let section_slug =
                    string.lowercase(string.replace(theme_cfg.name, " ", "-"))
                    <> "-"
                    <> int.to_string(i + 1)
                    <> "-"
                    <> string.replace(sec.section_type, " ", "-")

                  wisp.log_info("Saving section: " <> section_slug)
                  let p =
                    post.new_post(
                      section_slug,
                      sec.title,
                      section_slug,
                      sec.content,
                    )
                    |> post.with_status(post.Published)
                    |> post.with_section_type(sec.section_type)

                  post.save_post(db, p)
                })

              let resp =
                json.object([
                  #("name", json.string(theme_cfg.name)),
                  #("bg_color", json.string(theme_cfg.bg_color)),
                  #("text_color", json.string(theme_cfg.text_color)),
                  #("accent_color", json.string(theme_cfg.accent_color)),
                  #("border_color", json.string(theme_cfg.border_color)),
                  #("card_bg", json.string(theme_cfg.card_bg)),
                  #("font_family", json.string(theme_cfg.font_family)),
                  #("layout_style", json.string(theme_cfg.layout_style)),
                  #("shadow_depth", json.string(theme_cfg.shadow_depth)),
                  #("border_radius", json.string(theme_cfg.border_radius)),
                  #("spacing_scale", json.string(theme_cfg.spacing_scale)),
                  #("custom_flourish", json.string(theme_cfg.custom_flourish)),
                ])
                |> json.to_string
              wisp.ok() |> wisp.json_body(resp)
            }
            Error(e) ->
              wisp.internal_server_error()
              |> wisp.json_body("{\"error\": \"" <> e <> "\"}")
          }
        }
      }
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}

pub fn handle_sync(
  req: Request,
  db: aarondb.Db,
  _cfg: config.Config,
) -> Response {
  case req.method {
    http.Post -> {
      use body <- wisp.require_string_body(req)
      case json.parse(body, decode.list(sync_fact_decoder())) {
        Ok(facts) -> {
          let facts =
            list.map(facts, fn(f) {
              let f: SyncFact = f
              #(fact.deterministic_uid(f.eid), f.attr, fact.Str(f.val))
            })
          let _ = aarondb.transact(db, facts)
          wisp.ok()
          |> wisp.json_body("{\"status\": \"synced\"}")
        }
        Error(_) -> wisp.bad_request("Invalid Fact Sync Batch")
      }
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}

pub fn handle_list_posts(db: aarondb.Db) -> Response {
  let posts = post.get_all_published(db)
  let json_posts =
    json.array(posts, fn(p) {
      json.object([
        #("id", json.string(post.get_id(p))),
        #("title", json.string(post.get_title(p))),
        #("slug", json.string(post.get_slug(p))),
        #("section_type", json.string(post.get_section_type(p))),
      ])
    })
  let resp = json.to_string(json_posts)
  wisp.ok() |> wisp.json_body(resp)
}

pub fn handle_search(req: Request, db: aarondb.Db) -> Response {
  let query =
    wisp.get_query(req)
    |> list.key_find("q")
    |> result.unwrap("")

  let matches = case query {
    "" -> []
    q -> search.search_published_posts(db, q)
  }

  let json_matches =
    json.array(matches, fn(m) {
      json.object([
        #("id", json.string(post.get_id(m.post))),
        #("title", json.string(post.get_title(m.post))),
        #("slug", json.string(post.get_slug(m.post))),
        #("score", json.float(m.score)),
      ])
    })
  let resp = json.to_string(json_matches)
  wisp.ok() |> wisp.json_body(resp)
}

pub fn handle_media_upload(req: Request, _cfg: config.Config) -> Response {
  case req.method {
    http.Post -> {
      use bits <- wisp.require_bit_array_body(req)
      let ext =
        wisp.get_query(req)
        |> list.key_find("ext")
        |> result.unwrap("png")

      case storage.store(storage.default_local_adapter(), bits, ext) {
        Ok(asset) -> {
          let resp =
            json.object([
              #("status", json.string("uploaded")),
              #("hash", json.string(asset.hash)),
              #("mime_type", json.string(asset.mime_type)),
              #("public_url", json.string(asset.public_url)),
              #("size_bytes", json.int(asset.size_bytes)),
            ])
            |> json.to_string
          wisp.ok() |> wisp.json_body(resp)
        }
        Error(e) -> wisp.bad_request("Upload validation failed: " <> e)
      }
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}
