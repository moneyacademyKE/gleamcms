import aarondb
import gleamcms/config
import gleamcms/server/api
import gleamcms/server/auth
import gleamcms/server/static
import wisp.{type Request, type Response}

pub type PublishRequest =
  api.PublishRequest

pub type SyncFact =
  api.SyncFact

pub type SaveRequest =
  api.SaveRequest

const max_request_body_size = 1_048_576

pub fn handle_request(
  req: Request,
  db: aarondb.Db,
  cfg: config.Config,
) -> Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  let req = wisp.set_max_body_size(req, max_request_body_size)
  use req <- wisp.handle_head(req)
  use req <- wisp.csrf_known_header_protection(req)
  route_request(req, db, cfg) |> static.add_security_headers
}

fn route_request(req: Request, db: aarondb.Db, cfg: config.Config) -> Response {
  case wisp.path_segments(req) {
    ["admin", ..rest] ->
      case rest {
        ["login"] -> auth.handle_login(req, cfg)
        _ -> {
          use <- auth.require_admin(req, cfg)
          case rest {
            [] -> static.serve_editor(req)
            ["stats"] -> api.serve_stats(req, db)
            _ -> wisp.not_found()
          }
        }
      }
    ["health"] -> api.handle_health(db)
    ["search"] -> static.serve_search(req, db)
    ["static", ..file] -> static.serve_static(req, file)
    ["gleamcms_output", ..file] -> static.serve_output(req, file, cfg)
    ["sites"] -> static.serve_sites(db, cfg)
    ["api", ..rest] -> {
      use <- auth.require_admin(req, cfg)
      case rest {
        ["posts"] -> api.handle_list_posts(db)
        ["search"] -> api.handle_search(req, db)
        ["media", "upload"] -> api.handle_media_upload(req, cfg)
        ["publish"] -> api.handle_publish(req, db)
        ["save"] -> api.handle_save(req, db)
        ["facts", "sync"] -> api.handle_sync(req, db, cfg)
        ["generate"] -> api.handle_generate(req, db, cfg)
        ["ai", "design"] -> api.handle_ai_design(req, db)
        _ -> wisp.not_found()
      }
    }
    _ -> static.serve_home(req)
  }
}
