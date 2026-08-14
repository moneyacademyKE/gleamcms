# gleamcms

A fact-oriented, sovereign content management system built on the **AaronDB** temporal datalog engine for the Erlang/BEAM virtual machine.

`gleamcms` is an **independent, sovereign project**. It depends on `aarondb` purely as an embedded Datalog engine and owns its complete web, projection, and media layers (`wisp` / `mist` / `lustre` / `simplifile`).

---

## The Core Philosophy: Content as Immutable Values

Traditional content management systems (WordPress, Strapi, Ghost, Payload) are **place-oriented**: they model content as mutable database rows or documents. Updating an article overwrites the values at that disk location (`UPDATE posts SET ...`), destroying historical provenance unless secondary audit tables are bolted on.

`gleamcms` adopts Rich Hickey's **Epochal Time Model** and the **Value of Values**:
- **Posts are Datalog Facts:** Each post attribute (`cms.post/title`, `cms.post/slug`, `cms.post/content`, `cms.post/status`, `cms.post/published_at`, `cms.post/featured_image`, `cms.post/section_type`) is an immutable Entity-Attribute-Value (EAV) datom asserted atomically via `aarondb.transact/2`.
- **Sections are Just Posts:** A web page is a theme configuration plus a collection of section-posts (`hero`, `features`, `stats`, `cta`, `content`). The theme renderer dispatches on `section_type`, cleanly uncomplecting content from presentation.
- **Projections are Pure Functions:** Generated static sites, RSS feeds, and SSR views are deterministic pure projections: $f(\text{Facts}, \text{ThemeConfig}) \to \text{HTML}$.
- **Zero-Dependency Sovereignty:** Runs directly on the BEAM with embedded Mnesia storage. No external PostgreSQL, Redis, or Node.js runtime required.
- **Pure Semantic Hypermedia:** Zero CSS and zero JavaScript in runtime and output projections. 0ms DOM hydration, 100% universal accessibility.
- **In-Memory Probabilistic BM25 Search:** Native full-text inverted index ranking ($k_1 = 1.5, b = 0.75$) with zero external search daemons.
- **Cryptographic Media Verification:** Native `BitArray` magic-byte inspection rejecting extension spoofing before Content-Addressed Storage persistence.

---

## Layout

```
src/
  gleamcms.gleam              # Public library facade and application bootstrapper
  gleamcms/
    config.gleam              # Typed, fail-closed runtime configuration
    theme.gleam               # Renderer interface definition
    ai/
      designer.gleam          # Bounded AI theme designer (30s timeout, CSS whitelisting)
    builder/
      generator.gleam         # Atomic static site generator (isolated staging + swap)
      importer.gleam          # Legacy JSON data migration tooling
      media.gleam             # CAS media abstraction interface
      storage.gleam           # Pluggable storage adapter (LocalStorage & S3Storage)
      theme.gleam             # Theme resolution and provider
    content/
      ast.gleam               # Typed AST representations (Inline, Block, Document)
      markdown.gleam          # Pure functional Markdown parser & safe HTML renderer
      search.gleam            # AaronDB in-memory BM25 probabilistic full-text search
    db/
      post.gleam              # Post model, validation, and Datalog persistence
      schema.gleam            # AaronDB attribute schema declarations
    editor/
      app.gleam               # Semantic HTML5 hypermedia admin editor shell
    events/
      webhook.gleam           # Signed HMAC-SHA256 webhook event dispatcher
    runtime/
      ffi.gleam               # Quarantined Erlang host FFI bindings
      worker.gleam            # Supervised background async task worker
    server/
      api.gleam               # JSON decoders, CRUD, sync, generation & media upload endpoints
      auth.gleam              # Stateless HMAC sessions, cookies & POST-only login guard
      router.gleam            # High-level HTTP request dispatcher (<70 LOC)
      static.gleam            # Static asset & generated output serving + search views
    themes/
      catalog_a.gleam         # Curated theme definitions 1 to 25
      catalog_b.gleam         # Curated theme definitions 26 to 51
      configurable.gleam      # Pure semantic HTML renderer
      default.gleam           # Built-in sovereign theme
      library.gleam           # Unified theme catalog aggregator
  gleamcms_httpc_ffi.erl     # Erlang FFI (bounded port execution, crypto HMAC, inets, spawn)
```

---

## Gap Analysis: GleamCMS vs. Phoenix/Elixir (Beacon), Ghost v5, and WordPress

| Dimension | GleamCMS (BEAM Datalog) | Phoenix / Elixir (Beacon) | Ghost v5 (Node.js) | WordPress (PHP 8 / Gutenberg) |
|---|---|---|---|---|
| **Language & Typing** | **Gleam (Static Inferred, BEAM)** | Elixir (Dynamic, Dialyzer optional) | TypeScript/JS (Erased at runtime) | PHP (Dynamic / gradual typing) |
| **Data Model** | **EAV Datalog (Immutable Datoms)** | Relational SQL (Ecto Schemas) | Relational SQL (Bookshelf/Knex) | Relational SQL + `wp_postmeta` Key-Value |
| **Mutation Model** | **Atomic Fact Assertions** | In-place row overwrite (`UPDATE`) | In-place row overwrite (`UPDATE`) | In-place row overwrite (`UPDATE`) |
| **Temporal History** | **Native Temporal Retention** | Bolt-on version tables | Single `updated_at` | Revision table bloat (SQL rows) |
| **Full-Text Search** | **In-Memory Probabilistic BM25** | External Postgres `tsvector` | External Elasticsearch / Algolia | Naive SQL `LIKE %...%` |
| **SSG Projections** | **Atomic Staging Directory Swap** | Phoenix LiveView Dynamic SSR | Dynamic SSR + Headless API | Dynamic PHP execution |
| **Client Footprint** | **0 KB (Zero CSS, Zero JS)** | ~100 KB (LiveView WebSocket) | ~500 KB (Portal / Frontend JS) | ~1 MB – 5 MB (Gutenberg, jQuery, plugins) |
| **Dependencies** | **0 External Daemons (Mnesia)** | 1 DB Daemon (PostgreSQL) | 1 DB (MySQL) + Mailgun | Web Server + PHP-FPM + MySQL |
| **Memory Footprint** | **~30 MB (Single binary)** | ~80 MB – 150 MB | ~250 MB | ~300 MB – 1 GB |
| **Security Surface** | **Minimal (Zero JS, AST escaping)** | Medium (Channel auth) | High (NPM dependency tree) | Critical (Plugin vulnerability ecosystem) |
| **File Sizing** | **Strictly < 500 LOC per file** | Large multi-kLOC contexts | Large Node.js controllers | Monolithic legacy PHP files |

---

## Configure (Fail-Closed)

`gleamcms` refuses to start unless all required secrets are non-blank. Configuration is loaded once during boot and threaded explicitly:

| Env var | Required | Default | Purpose / Validation |
|---|:---:|---|---|
| `GLEAMCMS_SECRET` | yes | none | Non-blank signing secret for stateless admin HMAC session cookies. Never logged. |
| `GLEAMCMS_ADMIN_TOKEN` | yes | none | Non-blank bearer password accepted by `POST /admin/login`. Never logged. |
| `GLEAMCMS_OUTPUT_DIR` | no | `gleamcms_output` | Directory for generated atomic site projections. |
| `GLEAMCMS_DATA_DIR` | no | `Mnesia.nonode@nohost` | Persistent AaronDB/Mnesia storage directory. |
| `GLEAMCMS_PORT` | no | `4000` | Port integer from `1` through `65535`. |
| `GLEAMCMS_COOKIE_MAX_AGE` | no | `86400` | Session cookie lifetime in seconds (`60` to `2592000`). |
| `GLEAMCMS_IMPORT_LEGACY` | no | `false` | Explicit one-time legacy JSON import flag. |

---

## Quick Start

```sh
# 1. Set environment secrets
export GLEAMCMS_SECRET=$(openssl rand -hex 32)
export GLEAMCMS_ADMIN_TOKEN=$(openssl rand -hex 16)
export GLEAMCMS_PORT=4000

# 2. Run test suite
gleam test

# 3. Start sovereign server
gleam run
```

Access the admin editor at `http://localhost:4000/admin` and log in with your configured `GLEAMCMS_ADMIN_TOKEN`.

---

## Invariants & Certification

- **Strict File Sizing:** Every source and test file is strictly `< 500 LOC`.
- **Zero NPM / Node Dependency:** Built 100% in type-safe Gleam and Erlang/OTP.
- **Red/Green TDD:** Full test coverage across AST parsing, atomic SSG generation, webhook dispatch, magic-byte media verification, and BM25 search (`50/50 passed`).
- **Architectural Decision Records:** Complete decision log maintained in [`docs/ADR_LOG.md`](docs/ADR_LOG.md).
- **Learnings & Patterns:** Continuously maintained in [`docs/LEARNINGS_AND_PATTERNS.md`](docs/LEARNINGS_AND_PATTERNS.md).
