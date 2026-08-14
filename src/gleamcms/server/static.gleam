import aarondb
import gleam/list
import gleam/result
import gleam/string
import gleamcms/builder/generator
import gleamcms/config
import gleamcms/content/search
import gleamcms/db/post
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
    "default-src 'self'; script-src 'none'; style-src 'none'; img-src 'self' data:; object-src 'none'; base-uri 'self'; frame-ancestors 'none'",
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
  <title>GleamCMS — Sovereign Content</title>
</head>
<body>
  <header>
    <h1>GleamCMS</h1>
    <p>A fact-oriented, sovereign content management system built on the AaronDB Datalog engine.</p>
    <nav>
      <strong><a href=\"/admin\">Open Studio</a></strong> |
      <a href=\"/sites\">Generated Sites</a> |
      <a href=\"/health\">Health Check</a>
    </nav>
  </header>
  <hr />
  <main>
    <section>
      <h2>Architecture & Capabilities</h2>
      <ul>
        <li><strong>Pure Gleam:</strong> 100% type-safe functional codebase on Erlang/BEAM.</li>
        <li><strong>Zero CSS, Zero JavaScript:</strong> Pure semantic HTML5 hypermedia engine.</li>
        <li><strong>AaronDB Datalog:</strong> Content modeled as immutable fact datoms.</li>
        <li><strong>Atomic SSG Projections:</strong> Isolated staging directory swaps.</li>
        <li><strong>CAS Media Storage:</strong> Content-addressed SHA-256 asset storage.</li>
      </ul>
    </section>
  </main>
  <hr />
  <footer>
    <p><small>&copy; 2026 Sovereign Individual. Pure Gleam (Zero CSS, Zero JS).</small></p>
  </footer>
</body>
</html>"
  wisp.ok()
  |> wisp.html_body(html)
}

pub fn serve_editor(req: Request) -> Response {
  let query = wisp.get_query(req)
  let html = case list.key_find(query, "template") {
    Ok("hero") ->
      editor.render_with_template(
        "Transform Ideas Into Sovereign Reality",
        "hero-banner",
        "# Transform Ideas Into Sovereign Reality\n\nBuild lightning-fast, fact-oriented digital properties without accidental complexity.\n\n[Explore Architecture](/about) · [Get Started](https://gleam.run)",
        "hero",
      )
    Ok("features") ->
      editor.render_with_template(
        "Core Architectural Capabilities",
        "core-features",
        "## Architectural Pillars\n\n- **Pure Datalog Core**: Content modeled as immutable fact datoms.\n- **Atomic Projections**: Zero partial build tearing on static outputs.\n- **Sovereign Single-Binary**: Self-hosted on the BEAM VM with 30MB footprint.",
        "features",
      )
    Ok("stats") ->
      editor.render_with_template(
        "System Performance Metrics",
        "system-stats",
        "## Real-time Metrics\n\n- **51** Curated Native Themes\n- **30ms** Average Dynamic Latency\n- **100%** Type Safety on BEAM\n- **0** External Database Daemons",
        "stats",
      )
    Ok("testimonial") ->
      editor.render_with_template(
        "Architect Testimonials",
        "architect-testimonial",
        "> \"GleamCMS simplified our entire publishing infrastructure. We eliminated three database daemons and gained temporal audit history for free.\"\n>\n> — **Alex Mercer**, Principal Engineer at Sovereign Systems",
        "content",
      )
    Ok("pricing") ->
      editor.render_with_template(
        "Transparent Deployment Plans",
        "pricing-plans",
        "## Deployment Tiers\n\n- **Sovereign Edge**: Open source single-binary node.\n- **Studio Pro**: AI Theme Synthesis & Webhook Dispatch.\n- **Enterprise Mesh**: Multi-node Datalog cluster synchronization.",
        "content",
      )
    Ok("article") ->
      editor.render_with_template(
        "The Epochal Time Model in Modern CMS Architecture",
        "epochal-time-model",
        "# The Epochal Time Model in Modern CMS Architecture\n\nIn conventional databases, updating a row destroys the previous state. By modeling changes as immutable values, we retain complete historical provenance by default.\n\n```gleam\n// Content as immutable Datalog facts\naarondb.transact(db, [\n  fact.str(\"cms.post/title\", \"Sovereign Web\"),\n  fact.str(\"cms.post/status\", \"published\")\n])\n```\n\n### Why Values Matter\nWhen content is treated as an immutable value, static site generation becomes a pure deterministic projection function.",
        "content",
      )
    _ -> editor.render()
  }
  wisp.ok()
  |> wisp.html_body(html)
}

pub fn serve_sites(_db: aarondb.Db, cfg: config.Config) -> Response {
  let sites = generator.list_generated(cfg)
  let items =
    list.map(sites, fn(slug) {
      "<li><strong><a href=\"/gleamcms_output/"
      <> slug
      <> "/index.html\">"
      <> slug
      <> "</a></strong> (<a href=\"/gleamcms_output/"
      <> slug
      <> "/feed.xml\">RSS Feed</a>)</li>"
    })
  let body = case sites {
    [] ->
      "<p>No sites generated yet. Open the <a href=\"/admin\">Studio</a> to generate one.</p>"
    _ -> "<ul>" <> string.join(items, "\n") <> "</ul>"
  }
  let html = "<!DOCTYPE html><html lang=\"en\"><head>
  <meta charset=\"UTF-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
  <title>GleamCMS — Generated Sites Directory</title>
</head><body>
  <header>
    <h1>Generated Static Projections</h1>
    <nav><a href=\"/admin\">← Back to Studio</a> | <a href=\"/\">Home</a> | <a href=\"/search\">Search</a></nav>
  </header>
  <hr />
  <main>" <> body <> "</main>
  <hr />
  <footer><p><small>&copy; 2026 Sovereign Individual. Built with Pure Gleam.</small></p></footer>
</body></html>"
  wisp.ok()
  |> wisp.html_body(html)
}

pub fn serve_search(req: Request, db: aarondb.Db) -> Response {
  let query =
    wisp.get_query(req)
    |> list.key_find("q")
    |> result.unwrap("")

  let results = case query {
    "" -> []
    q -> search.search_published_posts(db, q)
  }

  let result_items =
    list.map(results, fn(match) {
      "<li><strong><a href=\"/posts/"
      <> post.get_slug(match.post)
      <> ".html\">"
      <> post.get_title(match.post)
      <> "</a></strong> <small>(BM25 Score: "
      <> string.inspect(match.score)
      <> ")</small><p><small><em>"
      <> match.snippet
      <> "</em></small></p></li>"
    })

  let results_body = case query {
    "" ->
      "<p>Enter a query above to perform BM25 probabilistic full-text search.</p>"
    _ ->
      case result_items {
        [] -> "<p>No posts matched query: <em>" <> query <> "</em></p>"
        _ -> "<ul>" <> string.join(result_items, "\n") <> "</ul>"
      }
  }

  let html = "<!DOCTYPE html><html lang=\"en\"><head>
  <meta charset=\"UTF-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
  <title>GleamCMS — Full-Text Search</title>
</head><body>
  <header>
    <h1>AaronDB BM25 Full-Text Search</h1>
    <nav><a href=\"/\">Home</a> | <a href=\"/admin\">Studio</a> | <a href=\"/sites\">Sites</a></nav>
  </header>
  <hr />
  <main>
    <form method=\"GET\" action=\"/search\">
      <fieldset>
        <legend>Search Query</legend>
        <p>
          <label>Query: <input type=\"text\" name=\"q\" value=\"" <> query <> "\" required /></label>
          <button type=\"submit\">🔍 Search</button>
        </p>
      </fieldset>
    </form>
    <section>
      <h2>Search Results</h2>
      " <> results_body <> "
    </section>
  </main>
  <hr />
  <footer><p><small>&copy; 2026 Sovereign Individual. Powered by AaronDB BM25 Inverted Index.</small></p></footer>
</body></html>"

  wisp.ok()
  |> wisp.html_body(html)
}
