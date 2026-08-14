# gleamcms

A fact-oriented, sovereign content management system built on the **AaronDB** temporal datalog engine for the Erlang/BEAM virtual machine.

`gleamcms` is an **independent, sovereign project**. It depends on `aarondb` purely as an embedded Datalog engine and owns its complete web, projection, and media layers (`wisp` / `mist` / `lustre` / `simplifile`).

---

## The Core Philosophy: Content as Immutable Values

Traditional content management systems (WordPress, Strapi, Ghost, Payload) are **place-oriented**: they model content as mutable database rows or documents. Updating an article overwrites the values at that disk location (`UPDATE posts SET ...`), destroying historical provenance unless secondary audit tables are bolted on.

`gleamcms` adopts Rich Hickey's **Epochal Time Model** and the **Value of Values**:
- **Posts are Datalog Facts:** Each post attribute (`cms.post/title`, `cms.post/slug`, `cms.post/content`, `cms.post/status`, `cms.post/published_at`, `cms.post/featured_image`, `cms.post/section_type`) is an immutable Entity-Attribute-Value (EAV) datom asserted atomically via `aarondb.transact/2`.
- **Sections are Just Posts:** A web page is a theme configuration plus a collection of section-posts (`hero`, `features`, `stats`, `cta`, `content`). The theme renderer dispatches on `section_type`, cleanly uncomplecting content from presentation.
- **Projections are Pure Functions:** Generated static sites, RSS feeds, and SSR views are deterministic pure projections: `f(Facts, ThemeConfig) -> HTML`.
- **Zero-Dependency Sovereignty:** Runs directly on the BEAM with embedded Mnesia storage. No external PostgreSQL, Redis, or Node.js runtime required.

---

## Layout

```
src/
  gleamcms.gleam              # Application bootstrapper and listener
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
    db/
      post.gleam              # Post model, validation, and Datalog persistence
      schema.gleam            # AaronDB attribute schema declarations
    editor/
      app.gleam               # Lustre SSR admin editor shell
    events/
      webhook.gleam           # Signed HMAC-SHA256 webhook event dispatcher
    runtime/
      ffi.gleam               # Quarantined Erlang host FFI bindings
    server/
      api.gleam               # JSON decoders, CRUD, sync, generation & design endpoints
      auth.gleam              # Stateless HMAC sessions, cookies & POST-only login guard
      router.gleam            # High-level HTTP request dispatcher (<70 LOC)
      static.gleam            # Static asset & generated output serving + security headers
    themes/
      catalog_a.gleam         # Curated theme definitions 1 to 25
      catalog_b.gleam         # Curated theme definitions 26 to 51
      configurable.gleam      # Config-driven dynamic HTML/CSS renderer
      default.gleam           # Built-in sovereign dark/light theme
      library.gleam           # Unified theme catalog aggregator
  gleamcms_httpc_ffi.erl     # Erlang FFI (bounded port execution, crypto HMAC, inets)
```

---

## Gap Analysis: GleamCMS vs. External CMS Alternatives

| Dimension | GleamCMS (AaronDB) | Payload CMS v3 | Strapi v5 | Ghost v5 | Sanity Content Lake |
|---|---|---|---|---|---|
| **Data Model** | **EAV Datalog Facts (Immutable Datoms)** | Relational SQL / Document | Relational SQL (MySQL/PG) | Relational SQL (MySQL/SQLite) | JSON-LD Structured Documents |
| **Mutation Model** | **Atomic Fact Assertions** | In-place row overwrite | In-place row overwrite | In-place row overwrite | Document CRDT mutation |
| **Temporal History** | **Native Fact Retention** | Custom version tables | Draft/Publish duplicates | Single `updated_at` | Document history API |
| **Query Engine** | **Declarative Datalog Patterns** | TypeScript ORM builder | REST filters / GraphQL | Knex ORM queries | GROQ (Graph Queries) |
| **SSG Projections** | **Atomic Staging & Rename Swap** | Next.js Server Components | Headless API only | Dynamic SSR only | Headless API only |
| **Content Safety** | **AST Markdown Parsing & Escaping** | DOMPurify / Slate AST | Sanitized Rich Text | Lexical AST Renderer | Portable Text Serializer |
| **Webhooks & Events** | **Signed HMAC-SHA256 Payloads** | Custom lifecycle hooks | Custom webhook UI | Webhook integrations | Managed GROQ webhooks |
| **Auth Boundary** | **POST-Only Form + HMAC Cookies** | Scoped JWTs & Cookies | Role JWTs & Permissions | Password + 2FA / Session | OAuth / SAML SSO |
| **Runtime Footprint** | **~30 MB (Single BEAM node)** | ~250 MB (Node + SQL DB) | ~350 MB (Node + SQL DB) | ~200 MB (Node + MySQL) | Cloud SaaS (Proprietary) |
| **File Sizing** | **Strictly < 500 LOC per file** | Large multi-kLOC files | Large controllers | Large monoliths | Modular React components |

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
- **Red/Green TDD:** Full test coverage across AST parsing, atomic SSG generation, webhook dispatch, and storage adapters (`45/45 passed`).
- **Architectural Decision Records:** Complete decision log maintained in [`docs/ADR_LOG.md`](docs/ADR_LOG.md).
