# gleamcms

A fact-oriented, sovereign content management system built on the **AaronDB** datalog engine.

gleamcms is an **independent project**. It is not part of, and does not live
inside, `aarondb` or `bankai`. It depends on `aarondb` purely as a datalog
engine and owns its own web layer (wisp / mist / lustre / gleam_http /
simplifile).

## The idea

Posts are **datalog facts**, not rows. Each post is a set of facts on a shared
entity id (`cms.post/title`, `/slug`, `/content`, `/status`, `/section_type`,
`/id`), written atomically and queried with pattern tuples.

The composition trick: **sections are just posts**. A landing page is a theme
config plus a bag of section-posts (`hero`, `features`, `stats`, `cta`,
`content`). The theme renderer dispatches on `section_type`. So content and
presentation stay cleanly separable.

## Layout

```
src/
  gleamcms.gleam            # entry point: boots AaronDB + Wisp on the configured port
  gleamcms/
    ai/designer.gleam       # AI theme designer (gemini, shell-free)
    builder/generator.gleam # static site generator (per-theme HTML + RSS)
    builder/media.gleam     # CAS media store (SHA-256) + simulated IPFS pin
    db/post.gleam           # Post model + datalog persistence + sanitization
    db/schema.gleam         # attribute schema declarations
    editor/app.gleam        # lustre editor (SSR + hydrated)
    server/router.gleam     # all HTTP routes, auth, generation
    theme.gleam             # Theme type
    themes/library.gleam    # 51 hand-curated themes
    themes/configurable.gleam
    themes/default.gleam
  gleamcms_httpc_ffi.erl   # Erlang FFI (http, env, hmac, safe spawn)
```

## Configure (fail-closed)

`gleamcms` refuses to start unless both secrets are present and non-blank.
Configuration is loaded once during boot and then passed explicitly through the
request and generation layers. The process does not re-read environment
variables per request.

| Env var | Required | Default | Validation / purpose |
|---|---:|---|---|
| `GLEAMCMS_SECRET` | yes | none | Non-blank signing secret for the stateless admin session cookie. Never log its value. |
| `GLEAMCMS_ADMIN_TOKEN` | yes | none | Non-blank password accepted by `/admin/login`. Never log its value. |
| `GLEAMCMS_OUTPUT_DIR` | no | `gleamcms_output` | Non-blank path for generated sites and output serving. The application creates generated subdirectories as needed. |
| `GLEAMCMS_PORT` | no | `4000` | Integer from `1` through `65535`; invalid values fail startup. |
| `GLEAMCMS_COOKIE_MAX_AGE` | no | `86400` | Integer seconds from `60` through `2592000` (30 days); invalid values fail startup. |

Startup diagnostics report only the configured port, output directory, and
whether admin access is enabled. They do not report secret or token values.
Invalid configuration is logged and the server does not start.

Generate disposable local credentials like this:

```sh
export GLEAMCMS_SECRET=$(openssl rand -hex 32)
export GLEAMCMS_ADMIN_TOKEN=$(openssl rand -hex 16)
export GLEAMCMS_OUTPUT_DIR=./gleamcms_output
export GLEAMCMS_PORT=4000
export GLEAMCMS_COOKIE_MAX_AGE=86400
gleam run   # serves on http://localhost:4000
```

Do not commit shell history, `.env` files, generated output, or production
credentials. The repository `.gitignore` excludes local build/Mnesia state and
environment files.

## Dependency note

gleamcms expects **aarondb as a pure datalog core** — the 74-module engine with
zero web dependencies. If resolving `aarondb` from hex pulls in a `mist`
constraint that conflicts with gleam_stdlib 1.x, you are hitting aarondb's
*bundled* CMS (the old layout this project was split out of). The fix is to
point `aarondb` at its split core build, or vendor the datalog engine. gleamcms
itself pins `gleam_stdlib >= 1.0.0`.
