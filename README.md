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
  gleamcms.gleam            # entry point: boots AaronDB + Wisp on :4000
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

## Configure (required — fail-closed)

gleamcms refuses to run without explicit secrets. Set these before `gleam run`:

| Env var | Purpose | Required |
|---|---|---|
| `GLEAMCMS_SECRET` | Long random string; signs the admin session cookie. **Server refuses to start if unset.** | yes |
| `GLEAMCMS_ADMIN_TOKEN` | The password typed at `/admin/login`. Login is disabled (fail-closed) if unset. | yes |
| `GLEAMCMS_OUTPUT_DIR` | Where generated sites are written/served from. Defaults to `./gleamcms_output`. | no |

```sh
export GLEAMCMS_SECRET=$(openssl rand -hex 32)
export GLEAMCMS_ADMIN_TOKEN=$(openssl rand -hex 16)
gleam run   # serves on http://localhost:4000
```

## Dependency note

gleamcms expects **aarondb as a pure datalog core** — the 74-module engine with
zero web dependencies. If resolving `aarondb` from hex pulls in a `mist`
constraint that conflicts with gleam_stdlib 1.x, you are hitting aarondb's
*bundled* CMS (the old layout this project was split out of). The fix is to
point `aarondb` at its split core build, or vendor the datalog engine. gleamcms
itself pins `gleam_stdlib >= 1.0.0`.
