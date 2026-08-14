import aarondb
import gleam/list
import gleam/string
import gleamcms/builder/generator
import gleamcms/config
import gleamcms/editor/app as editor
import wisp.{type Request, type Response}

pub fn add_security_headers(resp: Response) -> Response {
  resp
  |> wisp.set_header("x-content-type-options", "nosniff")
  |> wisp.set_header("x-frame-options", "DENY")
  |> wisp.set_header("referrer-policy", "no-referrer")
  |> wisp.set_header(
    "permissions-policy",
    "camera=(), microphone=(), geolocation=()",
  )
  |> wisp.set_header(
    "content-security-policy",
    "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data:; object-src 'none'; base-uri 'self'; frame-ancestors 'none'",
  )
}

pub fn serve_static(req: Request, _file: List(String)) -> Response {
  let assert Ok(priv) = wisp.priv_directory("gleamcms")
  use <- wisp.serve_static(req, under: "/static", from: priv <> "/static")
  wisp.not_found()
}

pub fn serve_output(
  req: Request,
  _file: List(String),
  cfg: config.Config,
) -> Response {
  use <- wisp.serve_static(
    req,
    under: "/gleamcms_output",
    from: config.output_dir(cfg),
  )
  wisp.not_found()
}

pub fn serve_home(_req: Request) -> Response {
  let html =
    "<!DOCTYPE html>
<html lang=\"en\">
<head>
  <meta charset=\"UTF-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
  <title>GleamCMS - Sovereign Content</title>
  <style>
    :root { --bg: #0f172a; --text: #f8fafc; --accent: #3b82f6; }
    body { font-family: 'Inter', sans-serif; background: var(--bg); color: var(--text); margin: 0; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
    .card { background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.1); border-radius: 16px; padding: 3rem; max-width: 500px; text-align: center; backdrop-filter: blur(12px); }
    h1 { font-size: 2.5rem; margin-bottom: 0.5rem; }
    h1 span { color: var(--accent); }
    p { opacity: 0.7; margin-bottom: 2rem; }
    a { display: inline-block; background: var(--accent); color: #fff; text-decoration: none; padding: 0.75rem 1.5rem; border-radius: 8px; font-weight: 600; margin: 0.25rem; }
    a.ghost { background: transparent; border: 1px solid var(--accent); color: var(--accent); }
    .status { margin-top: 2rem; font-size: 0.8rem; opacity: 0.4; }
  </style>
</head>
<body>
  <div class=\"card\">
    <h1>Gleam<span>CMS</span></h1>
    <p>A Fact-Oriented, Sovereign Content Management System built on AaronDB v2.1.0.</p>
    <a href=\"/admin\">Admin Editor</a>
    <a class=\"ghost\" href=\"/health\">Health Check</a>
    <div class=\"status\">⚡ 50 Themes &bull; CAS Media &bull; Datalog Engine</div>
  </div>
</body>
</html>"
  wisp.ok()
  |> wisp.html_body(html)
}

pub fn serve_editor(_req: Request) -> Response {
  let html = editor.render()
  wisp.ok()
  |> wisp.html_body(html)
}

pub fn serve_sites(_db: aarondb.Db, cfg: config.Config) -> Response {
  let sites = generator.list_generated(cfg)
  let cards =
    list.map(sites, fn(slug) {
      "<a class=\"site-card\" href=\"/gleamcms_output/"
      <> slug
      <> "/index.html\">"
      <> "<div class=\"site-name\">"
      <> slug
      <> "</div>"
      <> "<div class=\"site-links\">"
      <> "<span>index</span> · <span>rss</span>"
      <> "</div></a>"
    })
  let body = case sites {
    [] ->
      "<p style='color:#94a3b8'>No sites generated yet. Use <code>POST /api/generate</code> first.</p>"
    _ -> string.join(cards, "\n")
  }
  let html = "
<!DOCTYPE html><html lang=\"en\"><head>
  <meta charset=\"UTF-8\">
  <title>GleamCMS — Generated Sites</title>
  <style>
    :root{--bg:#0f172a;--card:rgba(255,255,255,0.05);--accent:#3b82f6;--text:#f8fafc}
    body{font-family:monospace;background:var(--bg);color:var(--text);padding:2rem;margin:0}
    h1{margin-bottom:2rem}a{color:inherit;text-decoration:none}
    .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:1rem}
    .site-card{background:var(--card);border:1px solid rgba(255,255,255,0.08);border-radius:12px;padding:1.25rem;transition:border-color .2s,transform .2s;display:block}
    .site-card:hover{border-color:var(--accent);transform:translateY(-2px)}
    .site-name{font-weight:700;font-size:0.95rem;margin-bottom:0.5rem;color:var(--text)}
    .site-links{color:#64748b;font-size:0.8rem}
    .back{margin-bottom:1.5rem;display:inline-block;color:#64748b;font-size:0.85rem}
    .back:hover{color:var(--accent)}
  </style>
</head><body>
  <a class=\"back\" href=\"/admin\">← back to editor</a>
  <h1>🌐 Generated Sites</h1>
  <div class=\"grid\">" <> body <> "</div>
</body></html>"
  wisp.ok()
  |> wisp.html_body(html)
}
