import gleam/http
import gleam/int
import gleam/list
import gleam/string
import gleamcms/config
import gleamcms/runtime/ffi
import wisp.{type Request, type Response}

/// Stateless session cookie value: HMAC of a fixed payload under the secret.
/// Verification recomputes and compares, so no server-side session store is
/// needed and the value carries no secret material.
pub fn session_value(s: String) -> String {
  ffi.hmac_sha256(s, "gleamcms-admin-session-v1")
}

pub fn set_session_cookie(
  resp: Response,
  s: String,
  cfg: config.Config,
) -> Response {
  wisp.set_header(
    resp,
    "set-cookie",
    "gleamcms_session="
      <> session_value(s)
      <> "; Path=/; HttpOnly; SameSite=Strict; Max-Age="
      <> int.to_string(config.cookie_max_age(cfg)),
  )
}

pub fn require_admin(
  req: Request,
  cfg: config.Config,
  handler: fn() -> Response,
) -> Response {
  let s = config.secret(cfg)
  case s == "" {
    // Fail-closed: with no signing secret there is no way to issue or verify a
    // trusted session, so every admin route is refused.
    True ->
      wisp.response(403)
      |> wisp.html_body("Admin disabled: GLEAMCMS_SECRET is not configured.")
    False -> {
      let valid = "gleamcms_session=" <> session_value(s)
      let ok = case list.key_find(req.headers, "cookie") {
        Ok(c) -> string.contains(c, valid)
        Error(_) -> False
      }
      case ok {
        True -> handler()
        False -> wisp.redirect("/admin/login")
      }
    }
  }
}

pub fn handle_login(req: Request, cfg: config.Config) -> Response {
  let s = config.secret(cfg)
  let expected = config.admin_token(cfg)
  // Fail-closed: login is impossible until both the signing secret and the
  // admin token are configured.
  case s == "" || expected == "" {
    True ->
      wisp.response(403)
      |> wisp.html_body(
        "Login disabled. Set GLEAMCMS_SECRET and GLEAMCMS_ADMIN_TOKEN to enable admin access.",
      )
    False -> {
      let verify = fn(submitted: String) -> Response {
        case submitted == expected {
          True -> wisp.redirect("/admin") |> set_session_cookie(s, cfg)
          False ->
            wisp.response(200)
            |> wisp.html_body(login_page("Invalid token. Try again."))
        }
      }
      case req.method {
        http.Post -> {
          use body <- wisp.require_string_body(req)
          let submitted = case string.split(body, "token=") {
            [_, t, ..] -> string.trim(t)
            _ -> ""
          }
          verify(submitted)
        }
        _ -> {
          wisp.ok()
          |> wisp.html_body(login_page(""))
        }
      }
    }
  }
}

pub fn login_page(error: String) -> String {
  let err_html = case error {
    "" -> ""
    msg -> "<p style='color:#f87171;margin-bottom:1rem'>" <> msg <> "</p>"
  }
  "<!DOCTYPE html>
<html lang=\"en\"><head>
  <meta charset=\"UTF-8\">
  <title>GleamCMS Login</title>
  <style>
    :root{--bg:#0f172a;--card:rgba(255,255,255,0.05);--accent:#3b82f6;--text:#f8fafc}
    body{font-family:monospace;background:var(--bg);color:var(--text);display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0}
    .card{background:var(--card);border:1px solid rgba(255,255,255,0.1);border-radius:16px;padding:2.5rem;min-width:320px;text-align:center}
    h2{margin-bottom:1.5rem}input{width:100%;box-sizing:border-box;padding:.75rem 1rem;border-radius:8px;border:1px solid #334155;background:#1e293b;color:var(--text);font-family:monospace;margin-bottom:1rem}
    button{width:100%;padding:.75rem;background:var(--accent);color:#fff;border:none;border-radius:8px;font-weight:700;cursor:pointer;font-size:1rem}
  </style>
</head><body>
  <div class=\"card\">
    <h2>GleamCMS Login</h2>
    " <> err_html <> "
    <form method=\"POST\" action=\"/admin/login\">
      <input type=\"password\" name=\"token\" placeholder=\"Bearer Token\" autofocus>
      <button type=\"submit\">Enter Admin</button>
    </form>
  </div>
</body></html>"
}
