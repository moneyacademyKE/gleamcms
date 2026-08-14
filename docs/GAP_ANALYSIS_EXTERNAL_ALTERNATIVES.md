# GleamCMS Module Gap Analysis Against External Alternatives

**Date:** 2026-08-14 UTC  
**Repository:** `/Users/moe/Desktop/gleamcms`  
**Revision inspected:** `chore/gleamcms-provenance` (working tree contains uncommitted production-hardening changes)  
**Scope:** production-relevant application modules, runtime boundaries, scripts, CI, and release/operations artifacts  
**Verdict:** useful single-node prototype with a coherent fact-oriented core; **not yet a production-equivalent CMS or production-proven runtime**.

## Executive summary

GleamCMS has a clear idea: posts are facts, generated sites are projections, and themes are composable renderers. That is the strongest part of the design. The current implementation is small enough to understand and the explicit configuration threading is better than hidden per-request environment reads.

The gaps are not primarily “missing features.” They are boundary failures where production alternatives already provide tested contracts:

1. **Runtime and HTTP lifecycle:** the entrypoint starts Mist directly and sleeps forever; it does not expose an OTP application/supervision tree comparable to Phoenix/Plug or standard OTP deployment practice.
2. **Security boundary:** one shared admin token, a token-in-URL login path, no login throttling, no `Secure` cookie attribute, raw HTML interpolation, and a hand-rolled regex sanitizer create materially more risk than Payload/Strapi plus OWASP-recommended sanitization practices.
3. **Persistence semantics:** AaronDB gives an interesting fact model, but the CMS layer has no explicit schema version/migration contract, revision model, or restore validation that boots the restored data. Ecto/PostgreSQL and Payload provide stronger operationally familiar boundaries.
4. **Generation and media:** generation is a full filesystem projection with ignored write errors and no atomic publish/swap; media is local content-addressed storage with simulated IPFS pinning, not an object-storage contract.
5. **AI and browser boundaries:** Gemini output is parsed from free-form CLI text rather than requested as schema-constrained JSON; generated CSS is injected into a `<style>` element; the editor has an external JS asset but the state/effect path is still split between Lustre and imperative JavaScript.

**Recommendation:** keep AaronDB and the fact-oriented content model for the first production slice, but harden the surrounding boundaries before adding multi-user, multi-instance, or plugin complexity. Replacing the database now would be premature; replacing the unsafe/implicit edges is not.

## Evidence and confidence labels

- **Verified:** directly observed in the live repository files listed in the evidence column.
- **Inferred:** a consequence of the observed implementation or a comparison to documented alternative capabilities.
- **Unknown:** cannot be established from the local checkout; requires staging, load, failure-injection, or operator evidence.

Severity means:

- **P0:** release blocker; security, integrity, or operability risk.
- **P1:** serious hardening gap; address before meaningful growth or external users.
- **P2:** product/scale gap; acceptable only if the single-node product contract is explicit.
- **N/A:** not a meaningful substitute; comparison is limited to a reference principle.

## Comparison framework

Every boundary is compared on the same questions:

| Dimension | Question |
|---|---|
| Functional contract | Does the module provide the expected CMS capability and a stable API? |
| Correctness and integrity | Are validation, atomicity, consistency, recovery, and failure behavior explicit? |
| Security | Are trust boundaries, secrets, untrusted content, and authorization handled safely? |
| Operability | Can an operator supervise, observe, back up, restore, and roll back it? |
| Scale | What happens with more content, requests, editors, assets, or instances? |
| Ecosystem | Is the capability maintained and supported by a mature alternative? |
| Migration cost | What is the smallest change that closes the gap without needless coupling? |

Alternatives are classified as **direct substitutes** (Payload/Strapi for CMS, Phoenix/Plug for HTTP/auth, Eleventy for static generation, S3/MinIO for media), or **adjacent references** (OTP supervision, OWASP/DOMPurify, OpenID Connect, Gemini structured output, Lustre SSR/hydration, GitHub Actions). These are not claims that GleamCMS should become any one of them.

## Module inventory and comparison matrix

| Module/boundary | Responsibility | Alternative/reference | Severity | Main gap |
|---|---|---|---|---|
| `src/gleamcms.gleam` | Boot config, Mnesia directory, AaronDB, HTTP listener | OTP Application/Supervisor; Phoenix deployment | P0 | Direct startup plus `sleep_forever`; no application supervision tree or graceful lifecycle contract |
| `src/gleamcms/config.gleam` | Load and validate environment configuration | Phoenix runtime configuration | P1 | Good fail-closed validation, but configuration depends on `ai/designer` FFI and lacks typed secret/edge policy separation |
| `src/gleamcms/server/router.gleam` | Routes, auth, CSRF, headers, API handlers, static/output serving | Phoenix Router/Plug; Strapi/ Payload APIs | P0 | 592-line trust-boundary monolith, shared token auth, token in URL, weak API contract, raw interpolation, no rate limit |
| `src/gleamcms/db/post.gleam` | Post model, validation, sanitization, queries, persistence | Payload collections; Ecto schemas/Repo | P0 | Manual fact mapping, incomplete fields, regex sanitizer, no revisions/audit/optimistic concurrency, error translation loses detail |
| `src/gleamcms/db/schema.gleam` | AaronDB attribute declarations | Ecto migrations/schema; Payload collection config | P1 | Schema declares fields not persisted and has no migration/version lifecycle |
| `src/gleamcms/builder/generator.gleam` | HTML/RSS generation and showcase seed | Eleventy incremental builds; static-host build pipelines | P1 | Full rebuilds, ignored filesystem errors, non-atomic output, no dependency graph or cache invalidation |
| `src/gleamcms/builder/importer.gleam` | Legacy JSON import | Payload/Strapi import/migration tooling | P1 | Partial failures are swallowed, no dry run/idempotency/reporting/transaction boundary |
| `src/gleamcms/builder/media.gleam` | Local SHA-256 content-addressed assets | S3/MinIO object storage and versioning | P1 | Path/extension handling is unvalidated; simulated IPFS pin; no metadata, access policy, lifecycle, or durable remote store |
| `src/gleamcms/builder/theme.gleam` | Theme selection and fallback | CMS theme/plugin registry; Eleventy layouts | P2 | Unknown theme silently falls back, hiding configuration errors; no versioned theme contract |
| `src/gleamcms/theme.gleam` | Minimal renderer interface | Template/layout abstraction in Eleventy/Payload | P2 | Very small and composable, but no escaping/context type, asset contract, metadata, or renderer errors |
| `src/gleamcms/themes/configurable.gleam` | Config-driven HTML/CSS renderer | Template engines plus CSP-safe asset pipeline | P0 | Raw values are interpolated into HTML, CSS, title, links, and inline script; generated CSS is an injection boundary |
| `src/gleamcms/themes/default.gleam` | Built-in default renderer | Mature CMS templates/themes | P1 | Raw post title/content/slug interpolation; inline script and inline event handler weaken CSP and output safety |
| `src/gleamcms/themes/library.gleam` | Large static theme catalog | Theme packages/registries | P2 | 727-line data blob is easy to ship but hard to validate, version, preview, or extend without recompilation |
| `src/gleamcms/ai/designer.gleam` | Gemini CLI prompt, JSON decode, theme config | Gemini structured output; provider API/queue | P0 | Free-form CLI parsing, no semantic validation, arbitrary CSS accepted, no timeout/cancellation/quotas/audit |
| `src/gleamcms/editor/app.gleam` | Lustre SSR shell and editor model | Lustre hydration; Payload/Strapi admin | P1 | Server view and imperative `editor.js` duplicate behavior; save/generate effects are placeholders; no initial persisted model or CSRF-aware client contract |
| `priv/static/editor.js` | Browser event handlers, API calls, AI preview | Typed client generated from API contract | P1 | Uses `innerHTML`, no explicit CSRF token/header, no schema validation, no abort/retry/error model |
| `src/gleamcms_httpc_ffi.erl` | HMAC, env, Gemini subprocess, HTTP helper, Mnesia config | OTP ports/supervised workers; provider SDK | P0 | Unbounded subprocess output/lifetime, environment/FFI coupling, weak HTTP status contract, no telemetry or cancellation |
| `.github/workflows/ci.yml` | Format/build/test/smoke CI | GitHub Actions environments/attestations | P1 | Good local gates, but no hosted run/evidence in this inspection, no release artifact/provenance, staging or protected production environment |
| `scripts/smoke_test.sh` | Live HTTP regression test | Phoenix/Strapi integration suites | P1 | Valuable end-to-end coverage, but fixed assumptions and no concurrency, TLS proxy, malformed payload, or rate-limit tests |
| `scripts/restore_drill.sh` | Archive/extract Mnesia fixture | SQLite online backup; PostgreSQL WAL/PITR | P0 | Verifies files and archive checksum but does not boot the restored data or compare application content |
| Docs/release artifacts | Operations, threat model, persistence, promotion checklist | Mature deployment/runbook conventions | P1 | Honest and useful, but several gates remain operator-owned and unproven; no hosted/staging witness |

## Detailed findings

### 1. Runtime and HTTP lifecycle

**Current implementation — verified.** `src/gleamcms.gleam` configures logging, loads config, sets the Mnesia directory, creates the directory, initializes AaronDB schema, starts `wisp_mist.handler(...) |> mist.new() |> mist.port(...) |> mist.start()`, then calls `process.sleep_forever()`. There is no visible project-owned OTP `Application` callback or supervision tree in the source inventory.

**External reference.** OTP supervisors start, stop, monitor, and restart child processes, with explicit restart strategies and restart intensity limits ([OTP supervisor](https://www.erlang.org/doc/apps/stdlib/supervisor.html), [OTP application](https://www.erlang.org/doc/apps/kernel/application.html)). Phoenix/Plug documentation similarly recommends starting the HTTP handler under the application supervision tree in production ([Plug](https://hexdocs.pm/plug/readme.html), [Phoenix deployment](https://phoenix.hexdocs.pm/deployment.html)).

**Gap — P0.** A process supervisor outside the app may restart the whole OS process, but that is not equivalent to an application-owned lifecycle. Startup failures from `let assert`, Mnesia initialization, or Mist startup are not modeled as typed readiness failures. Graceful shutdown and restart ordering are not proven. The current smoke test proves restart behavior, not supervised failure recovery.

**Smallest useful next step.** Add an OTP application/supervision boundary around database initialization and HTTP serving, with bounded restart policy and an explicit readiness contract. Verify: kill a child, induce a failed startup, send SIGTERM, and confirm data remains intact and the service exits/restarts predictably.

### 2. Configuration boundary

**Current implementation — verified.** `config.load_with` validates non-blank secret/token, port, output/data paths, cookie max age, and import flag. Values are loaded once and threaded through request/generation functions. `config.gleam` imports `gleamcms/ai/designer` solely to call its `get_env` FFI.

**External reference.** Phoenix loads runtime configuration from environment at boot and separates deployment secrets from application configuration ([Phoenix deployment](https://phoenix.hexdocs.pm/deployment.html)).

**Gap — P1.** The positive design choice—boot-time typed configuration—is present. The boundary is nevertheless coupled to the AI module, so a core runtime configuration concern depends on an optional feature and FFI module. The config type also does not express deployment policy such as secure cookies, trusted proxy/host, TLS-required behavior, external object store, or rate-limit backend. Empty `data_dir` is checked, but path ownership and escape/permission policy are not.

**Recommendation.** Move environment access to a tiny runtime FFI/config adapter; keep `Config` as plain data. Add explicit edge/security fields only when a deployment needs them, rather than growing a global bag of options. Verify with deterministic config tests and a staging boot using the exact deployment contract.

### 3. Router, authentication, and API boundary

**Current implementation — verified.** `router.gleam` combines route dispatch, login, cookie verification, CSRF middleware, security headers, static serving, JSON decoding, persistence calls, generation, AI calls, and HTML pages. Admin auth is one shared environment token. The GET login path accepts `?token=...`; the session cookie is `HttpOnly`, `SameSite=Strict`, and `Max-Age`, but does not set `Secure`. API responses are hand-built JSON strings in several places.

**External alternatives.** Plug provides composable middleware for sessions, CSRF, request IDs, static files, SSL, telemetry, and parsers; Phoenix composes these through router pipelines ([Plug](https://hexdocs.pm/plug/readme.html), [Phoenix Plug](https://phoenix.hexdocs.pm/phoenix/plug.html)). Payload provides operation-scoped access control for create/read/update/delete and versions ([Payload access control](https://payloadcms.com/docs/access-control/overview), [collection access](https://payloadcms.com/docs/access-control/collections)). Strapi generates authenticated content APIs, filtering, pagination, and role permissions ([Strapi REST API](https://docs.strapi.io/cms/api/rest), [Users & Permissions](https://docs.strapi.io/cms/features/users-permissions)).

**Gaps — P0.**

- Token-in-URL login leaks credentials through browser history, referrers, logs, screenshots, and copied links.
- One shared token has no identity, role, revocation, per-user audit, or least privilege.
- No login rate limiting or lockout; the repository threat model explicitly defers it.
- Cookie lacks `Secure`; edge TLS is assumed rather than enforced by the app/deployment contract.
- `require_admin` is a single global gate, not operation-scoped authorization.
- Error and JSON handling are inconsistent; several responses concatenate untrusted strings into HTML/JSON.
- The router is 592 lines and is therefore hard to review as a security boundary.

**Recommendation.** First remove token-in-query login and add a proper POST-only login flow with a secure cookie policy, bounded attempts, and an explicit deployment proxy contract. Then split middleware/auth/API handlers by boundary. Do not add RBAC before the single-admin contract is secure and observable. Verify with log/referrer tests, cookie assertions, brute-force tests, malformed JSON tests, and authorization matrix tests.

### 4. Post model, persistence, and sanitization

**Current implementation — verified.** `Post` is an opaque type with title, slug, content, status, optional fields, and section type. `save_post` validates title/slug, sanitizes title/content, builds facts, and calls `aarondb.transact`. Queries manually reconstruct posts from rows. `published_at`, featured image, and tags are declared in the schema but not written by `save_post`. Content is sanitized by repeated regular expressions.

**External alternatives.** Payload collections generate local/REST/GraphQL APIs, schema-driven fields, access control, versions, and hooks ([Payload collections](https://payloadcms.com/docs/configuration/collections)); Ecto’s Repo abstracts persistence, translates constraint errors, supports transactions and migrations, and maps schemas to database values ([Phoenix Ecto](https://phoenix.hexdocs.pm/ecto.html)). OWASP recommends HTML sanitization for authored HTML and specifically recommends maintained sanitizers such as DOMPurify, with ongoing patching ([OWASP XSS prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet)).

**Gaps — P0/P1.**

- A regex sanitizer is not a parser-based HTML security boundary. It may miss browser parsing differentials, malformed markup, CSS/URL edge cases, and future bypasses.
- Titles, slugs, section types, theme values, and generated content are interpolated into multiple output contexts without context-specific escaping.
- The opaque type exposes no revision, updated-at, author, checksum, or optimistic-concurrency information.
- `save_post` does not persist all schema-declared attributes; schema and model can drift silently.
- Database errors become `"Database transaction failed"`, losing actionable cause and observability.
- No unique-slug conflict path is tested as a domain-level error.

**Recommendation.** Decide the content contract: plain text/Markdown or a restricted HTML subset. If authored HTML is required, use a maintained parser/sanitizer with an allowlist and sanitize at the final trust boundary; otherwise escape text and render Markdown through a maintained parser. Add explicit field serializers, revision metadata, conflict handling, and migration tests. Verify with a corpus of malformed and browser-specific payloads, not only a handful of regex examples.

### 5. Schema declarations

**Current implementation — verified.** `db/schema.gleam` registers attributes for title, slug, content, status, published_at, tags, and featured_image. The post writer currently persists only id, title, slug, content, status, and section type.

**External reference.** Ecto uses explicit migrations and rollback operations to evolve database schemas ([Ecto migrations](https://hexdocs.pm/ecto_sql/Ecto.Migration.html)); Payload collection configuration is the source for generated collection APIs and fields.

**Gap — P1.** Schema declarations are executable setup, not a migration history. There is no version marker, compatibility check, forward migration, rollback strategy, or proof that a restored/older data directory is compatible with the current application. Declaring fields that are not written makes the schema look richer than the actual persistence contract.

**Recommendation.** Keep AaronDB’s schema model, but add a versioned schema initialization/migration module and a test fixture for every supported upgrade path. Either persist optional fields or remove them from the active schema until implemented. Verify boot against old fixtures and fail closed on unsupported versions.

### 6. Static generation

**Current implementation — verified.** `generator.gleam` queries published posts, renders each theme to files, writes index/RSS, lists generated directories, and supports all/showcase builds. It creates directories and ignores some `simplifile.write` results. Output is written directly into the live directory.

**External alternative.** Eleventy supports collections, data cascades, declared dependencies, and incremental builds that rebuild only changed files/dependencies ([Eleventy incremental](https://www.11ty.dev/docs/usage/incremental/), [data cascade](https://www.11ty.dev/docs/data-cascade/), [collections](https://www.11ty.dev/docs/collections/)).

**Gaps — P1.** Full rebuilds are acceptable for a small catalog but do not establish scaling behavior. Direct writes can leave partially generated sites visible after a crash. Index/RSS write failures are discarded. RSS values and HTML values are interpolated without a context-safe serializer. A theme lookup silently falls back, so a typo can publish the wrong design.

**Recommendation.** Introduce a build-plan/result type: collect all render/write errors, write to a unique temporary directory, fsync/close where applicable, then atomically swap a completed site directory. Add deterministic output tests, invalid-theme errors, and a measured threshold before implementing incremental dependency tracking. Verify interruption during generation leaves the previous projection intact.

### 7. Legacy importer

**Current implementation — verified.** `builder/importer.gleam` reads a JSON list and calls `post.save_post` for each item. It ignores each save result and returns the input list length when decoding succeeds.

**External comparison.** Payload and Strapi treat content as schema-governed documents with validation, access, and explicit APIs rather than a best-effort loop ([Payload collections](https://payloadcms.com/docs/configuration/collections), [Strapi REST API](https://docs.strapi.io/cms/api/rest)).

**Gap — P1.** A result of “N imported” can mean zero successfully persisted records. Duplicate IDs/slugs, invalid posts, and mid-run failures are not reported or rolled back. There is no dry run, idempotency key, checkpoint, or import report.

**Recommendation.** Keep the importer as a one-time tool, not a boot side effect. Add dry-run validation, per-record outcomes, duplicate policy, and an explicit transaction/checkpoint strategy. Verify a fixture containing valid, invalid, duplicate, and restart cases.

### 8. Media storage

**Current implementation — verified.** `builder/media.gleam` hashes bytes with SHA-256 and writes `priv/static/media/<hash>.<extension>`. It logs deduplication and prints “Pinned to IPFS (Simulated).” The extension is accepted as a raw string; the directory is not created in this module.

**External alternatives.** S3 supports versioning and time-limited presigned upload/download URLs ([S3 versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html), [S3 presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html)). MinIO provides an S3-compatible API, versioning, lifecycle rules, and policy-controlled objects ([MinIO objects/versioning](https://docs.min.io/aistor/administration/objects-and-versioning/), [MinIO compatibility](https://docs.min.io/aistor/developers/s3-api-compatibility/)).

**Gap — P1.** Local CAS is a good deterministic primitive, but it is not durable object storage. It lacks MIME sniffing/content validation, size limits, metadata, authorization, remote backup, lifecycle, version/delete semantics, and safe extension/path normalization. The simulated IPFS message is operationally misleading.

**Recommendation.** Rename the simulation or remove the claim. Define a `MediaStore` boundary with local CAS for development and S3-compatible storage for production. Store content type, size, hash, and ownership as metadata; use generated URLs rather than exposing arbitrary paths. Verify traversal/extension tests, large-file limits, object existence, and restore behavior.

### 9. Theme abstraction and provider

**Current implementation — verified.** `theme.gleam` defines a minimal `Theme` with layout, post view, and archive view. `builder/theme.gleam` selects a configured theme and silently falls back to the first theme when a name is absent.

**External comparison.** Eleventy’s layout/data model and Payload’s collection configuration show mature systems making data/template relationships explicit and configurable ([Eleventy data](https://www.11ty.dev/docs/data/), [Payload collections](https://payloadcms.com/docs/configuration/collections)).

**Gap — P2, with a P1 correctness edge.** The tiny interface is composition-friendly and should be retained. The silent fallback is not: an invalid deployment or user selection can generate a valid-looking but wrong site. The interface has no renderer error, escaping/context type, asset manifest, metadata, or theme version.

**Recommendation.** Return `Result(Theme, ThemeError)` for named selection and reserve fallback for an explicit “default” request. Add a versioned theme contract only when external themes are actually needed. Verify invalid names fail visibly and each built-in theme renders a deterministic fixture.

### 10. Configurable renderer

**Current implementation — verified.** `themes/configurable.gleam` interpolates theme configuration and post values into HTML/CSS/URLs. It emits an inline script using `IntersectionObserver` and injects `custom_flourish` directly into a `<style>` block.

**External references.** OWASP distinguishes output encoding by context and warns that sanitization can be invalidated by later modification ([XSS prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet), [DOM XSS prevention](https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet)). The browser-facing safer direction is to use safe DOM APIs and constrained assets rather than raw HTML sinks.

**Gap — P0.** A theme config is treated as trusted code/data without proving that it is trusted. `font_family` reaches a remote stylesheet URL; colors, layout class, title/name, custom CSS, post title, and content cross contexts. A malicious or compromised AI result can become persistent CSS/HTML/script behavior in generated sites. The CSP permits `'unsafe-inline'` for scripts and styles, weakening the defense-in-depth boundary.

**Recommendation.** Replace free-form theme strings with validated enums/tokens and a constrained style model. Escape every text/attribute context, disallow arbitrary CSS by default, and move the fixed animation script to a static asset with a nonce/hash if inline code remains. Verify generated output with adversarial theme values and a browser security test, not only string absence checks.

### 11. Default renderer

**Current implementation — verified.** `themes/default.gleam` renders navigation, inline theme toggle JavaScript, post title/content, archive links, and footer. It directly interpolates post fields and uses an inline `onclick` handler.

**Gap — P1/P0 depending on content trust.** The renderer is simple, but raw title/content/slug values cross HTML and URL contexts. The inline handler requires `'unsafe-inline'` or will be blocked by a stricter CSP. The default renderer duplicates concerns that should be shared with a safe HTML/asset layer.

**Recommendation.** Make the renderer consume already-typed safe fragments or escaped text, use external JS/event listeners, and centralize URL construction. Add title/slug/content fixtures containing quotes, angle brackets, Unicode, and URL delimiters.

### 12. Theme catalog

**Current implementation — verified.** `themes/library.gleam` is a large compiled list of `ThemeConfig` values. It is simple, deterministic, and requires no runtime registry.

**External comparison.** Mature CMS and static-site ecosystems generally treat themes/layouts as versioned packages or configurable project assets, while Eleventy’s data/layout system keeps content data separate from templates ([Eleventy data cascade](https://www.11ty.dev/docs/data-cascade/)).

**Gap — P2.** The compiled catalog is not itself a production problem. Its limits are operational: every new theme requires a code change/rebuild; there is no schema validation at load, preview metadata, compatibility version, asset bundling, or user-defined theme lifecycle. The file is 727 lines, so review friction is already measurable.

**Recommendation.** Do not build a plugin ecosystem yet. First extract catalog data into validated versioned data files only if product demand requires runtime customization. Keep the static list if the product deliberately ships a fixed curated set.

### 13. AI designer

**Current implementation — verified.** `ai/designer.gleam` concatenates a system instruction and user prompt, invokes the local `gemini` executable through an Erlang port, splits free-form output on newline/`{`, extracts a final-looking JSON object, and decodes strings into `ThemeConfig`. `custom_flourish` is accepted as arbitrary text. The router saves generated sections before returning a response.

**External reference.** Gemini supports structured JSON output with JSON Schema, enums, required properties, and application-side semantic validation ([Gemini structured output](https://ai.google.dev/gemini-api/docs/structured-output), [Generate Content API](https://ai.google.dev/api/generate-content)).

**Gaps — P0.** Free-form CLI parsing is brittle and makes output boundaries ambiguous. JSON decoding checks shape but not semantic safety: color syntax, font names, layout values, section count, content size, and CSS are not constrained. The subprocess has no visible timeout, output cap, cancellation, retry policy, provider identity, cost budget, or audit trail. The router may persist partially generated sections before a later failure.

**Recommendation.** Request schema-constrained JSON through a bounded provider adapter, then validate domain invariants before persistence. Treat CSS as a separate explicit capability, ideally disabled or allowlisted. Put AI design into a job/request boundary with timeout and idempotency, and persist only after the complete result validates. Verify malformed output, timeout, oversized output, semantic-invalid output, and partial-write rollback.

### 14. Editor server/client boundary

**Current implementation — verified.** `editor/app.gleam` renders the editor shell through Lustre and ships `/static/editor.js`. Lustre events model fields, but `save_effect` is intentionally a no-op; imperative JavaScript performs save/generate/AI fetches. The server places theme names in a `data-themes` attribute.

**External reference.** Lustre documents SSR and manual hydration by serializing initial model state and starting the client with matching flags ([Lustre SSR/hydration](https://lustre.hexdocs.pm/guide/05-server-side-rendering.html)); its full-stack guide separates client/server applications and explicitly models API calls and initial state ([Lustre full-stack](https://lustre.hexdocs.pm/guide/06-full-stack-applications.html)). Payload and Strapi provide mature admin panels, validation, permissions, and API contracts ([Payload access control](https://payloadcms.com/docs/access-control/overview), [Strapi media/admin concepts](https://docs.strapi.io/cms/features/media-library)).

**Gap — P1.** The editor has two state systems: Lustre’s model and imperative DOM/fetch code. The server does not serialize a persisted post into the initial model, and the save/generate effects do not represent actual asynchronous outcomes. `data-themes` is hand-built JSON rather than encoded by a JSON serializer. The editor client does not visibly attach an explicit CSRF header, relying on Wisp’s known-header behavior.

**Recommendation.** Choose one boundary: either make the editor a deliberately imperative thin client with a documented API, or complete Lustre effects/hydration and make the model authoritative. Add API response types, CSRF/client deployment tests, and persisted edit loading before adding UI breadth.

### 15. Static editor asset

**Current implementation — verified.** `priv/static/editor.js` uses `innerHTML = ''` to clear the theme picker, `textContent` for option labels, imperative `fetch`, and direct `style`/`className` updates. It does not validate API response shape and does not abort requests or expose detailed errors.

**External reference.** OWASP’s DOM XSS guidance recommends safe DOM methods and avoiding untrusted data in HTML rendering methods ([DOM XSS prevention](https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet.html)).

**Gap — P1.** The current `innerHTML = ''` is not directly exploitable with a constant, but it establishes an unsafe sink in a security-sensitive editor and makes future changes riskier. AI response values are applied to CSS and class names without client-side validation. The client has no schema/version negotiation, request timeout, or CSRF failure UX.

**Recommendation.** Use DOM removal APIs, validate every response against a small client contract, constrain style values, and centralize fetch/error handling. Add browser tests for malformed API responses, rejected CSRF, slow requests, and malicious theme values.

### 16. Erlang FFI and external process boundary

**Current implementation — verified.** `gleamcms_httpc_ffi.erl` implements HMAC, environment access, `gemini` subprocess execution via `open_port`, Mnesia directory configuration, and a generic `httpc` POST helper. The Gemini port collects stdout until exit with no visible size/time bound. The HTTP helper only treats status 200 as success and starts inets/ssl per request.

**External reference.** OTP supervision and application docs define how long-lived workers and external resources should be started, monitored, and shut down ([OTP supervisor](https://www.erlang.org/doc/apps/stdlib/supervisor.html)). Gemini’s API provides a structured request/response contract that is more robust than scraping CLI output ([Gemini API](https://ai.google.dev/api/generate-content)).

**Gaps — P0/P1.** An unbounded child process can hang or consume memory. Port ownership and cleanup are local to the call, not supervised. `get_env` makes configuration depend on the AI module. HMAC input conversion is terse and has no key rotation/version policy. The HTTP helper’s narrow success handling and lack of timeout/options are not enough for a production integration boundary.

**Recommendation.** Isolate FFI by concern: runtime config, crypto, external AI provider, and optional HTTP client. Add bounded port execution, output caps, explicit timeouts, cancellation, and structured errors. Prefer a documented provider API over CLI scraping. Verify failure injection at each FFI boundary.

### 17. CI and release provenance

**Current implementation — verified.** `.github/workflows/ci.yml` runs format, build, tests, and the smoke test on push/PR using pinned Gleam/OTP versions. `docs/RELEASE.md` states no remote is configured and that staging evidence remains outstanding.

**External reference.** GitHub Actions supports environments, required reviewers, environment secrets, protected branches/tags, concurrency, artifacts, and attestations ([Actions](https://docs.github.com/actions), [workflow syntax](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions), [deployments/environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)).

**Gap — P1.** The workflow is a good local verification baseline, but no hosted CI result, release artifact, staging environment, deployment protection, or artifact attestation was verified here. CI credentials are intentionally test-only, which is correct; it also means CI does not exercise secret-store and proxy behavior.

**Recommendation.** Establish the canonical remote, require CI on protected branches, upload a reproducible artifact and verification witness, and add a separately protected staging job. Verify the exact artifact—not a rebuild—passes staging smoke before promotion.

### 18. Smoke test

**Current implementation — verified.** `scripts/smoke_test.sh` starts an isolated instance, checks health/home/editor/login/auth, publishes sanitized content, rejects a bad slug, generates output, restarts, and checks persistence/stateless session behavior.

**Gap — P1.** This is unusually valuable for a small project, but it tests one happy deployment shape. It does not test token leakage through query/referrer, brute-force behavior, secure cookies, concurrent writes, duplicate slugs, malformed AI output, output interruption, proxy headers, TLS, or restored-data boot. Its `curl` calls do not model a real edge/proxy deployment.

**Recommendation.** Keep it as the smoke gate and add focused negative/integration suites rather than making the script enormous. Add a separate security regression suite and a restore-boot test.

### 19. Restore drill

**Current implementation — verified.** `scripts/restore_drill.sh` creates an isolated fixture, archives it, extracts it, checks `datoms.DCD`, `schema.DAT`, and `LATEST.LOG`, and prints a checksum. `docs/RESTORE_DRILL.md` explicitly says this proves archive integrity and isolated extraction only.

**External comparison.** SQLite documents an online backup API designed to copy a live database without holding a continuous source lock ([SQLite backup](https://sqlite.org/backup.html)); PostgreSQL documents WAL-based crash recovery, online backup, and point-in-time recovery ([PostgreSQL WAL](https://www.postgresql.org/docs/18/wal-intro.html)). These systems expose well-known consistency and recovery contracts; this is a comparison of operational contract, not a claim that they are automatically better for this workload.

**Gap — P0.** The drill does not boot the restored directory, query expected facts, compare counts/content, or measure application RTO. A valid tar archive can still contain data the current binary cannot open. Mnesia consistency also depends on the complete directory and node/runtime assumptions.

**Recommendation.** Extend the drill to start the application against the extracted directory, authenticate, query a known fixture post, generate output, and record elapsed RTO. Preserve the failed directory and prove the process can roll back without destructive cleanup.

### 20. Operations, threat model, and persistence docs

**Current implementation — verified.** The repository contains operations, threat-model, persistence, staging, release-checklist, and restore-drill documents. They are explicit that production is blocked by TLS/proxy configuration, hosted CI/staging evidence, backup operator sign-off, and deferred controls such as rate limiting.

**Gap — P1.** The documents are more honest than the implementation’s green local checks, but operational ownership is still external to the repository. There is no machine-verifiable staging witness in this inspection, no alert wiring, no load profile, no supervised runtime evidence, and no tested rollback against a previous artifact.

**Recommendation.** Treat these documents as release gates, not evidence by themselves. Attach command output, exact revision, staging URL/evidence, backup checksum, restore boot result, and operator sign-off to a release witness.

## Prioritized roadmap

### P0 — release blockers

| Action | Why now | Verification signal |
|---|---|---|
| Put the application under an OTP supervision/application boundary | Prevents unclear startup, shutdown, and crash behavior | Child-failure, SIGTERM, restart-intensity, and data-preservation tests |
| Remove token-in-query login; add secure POST login and rate limiting | Current credential leakage and brute-force exposure are direct security risks | Query token never accepted; logs/referrers contain no credential; repeated attempts throttle; `Secure` cookie under TLS |
| Replace regex/raw HTML trust boundary | Stored XSS and context-confusion risk is larger than current tests show | Parser/allowlist corpus, escaped title/URL tests, browser CSP test, maintained sanitizer dependency review |
| Make generated output atomic and error-complete | A failed build must not publish a half-built site | Kill/interruption test leaves old output; failed writes are returned and logged |
| Make restore drill boot and query restored data | Archive extraction alone is not a recovery test | Restored process starts, authenticated query finds fixture, generation succeeds, RTO recorded |
| Constrain AI output and subprocess execution | AI is an untrusted input and currently writes persistent sections/CSS | Schema-constrained response, semantic validation, timeout/output cap, no partial persistence |
| Gate arbitrary fact sync or remove it from production routes | Generic fact mutation bypasses the post domain contract | Endpoint absent/disabled by default; authorized typed mutations only |
| Establish hosted CI/staging provenance | Local green is not deploy evidence | Protected branch CI result, exact artifact, staging smoke, release witness |

### P1 — hardening before growth

- Version AaronDB schema initialization and test old-data compatibility.
- Split router into middleware, auth, content API, generation, AI, and static/output modules.
- Add request IDs, structured logs, latency/error counters, and operator-visible generation/import reports.
- Introduce a media-store interface with local CAS and S3-compatible implementations.
- Add importer dry-run, idempotency, duplicate policy, and per-record result reporting.
- Add API response schemas and browser contract tests.
- Define trusted proxy/host/TLS policy and enforce `Secure` cookie behavior.
- Measure generation cost; only then implement incremental builds or a queue.

### P2 — product and scale

- Per-user identities and RBAC; consider OIDC rather than inventing a credential ecosystem. OpenID Connect standardizes identity claims and authorization-server integration ([OIDC Core](https://openid.net/specs/openid-connect-core-1_0.html)).
- Draft revisions, preview, scheduled publish, unpublish, and optimistic concurrency. Payload’s draft/version model is a useful reference ([Payload drafts](https://payloadcms.com/docs/versions/drafts)); Strapi provides draft/publish and scheduled release concepts ([Strapi draft/publish](https://docs.strapi.io/cms/features/draft-and-publish)).
- Search, filtering, pagination, tags, localization, and relationship/content-type modeling.
- Media metadata, folders, access policy, transformations, and version/lifecycle management.
- Incremental generation with explicit content/theme dependency graphs.
- Shared object storage and a deliberate multi-instance consistency model.

## Build versus adopt decisions

| Decision | Recommendation | Reason |
|---|---|---|
| Replace AaronDB now | **Do not** | The fact model is the product’s differentiator; the immediate failures are at HTTP, rendering, recovery, and auth boundaries. |
| Adopt Payload/Strapi wholesale | **Only if conventional CMS breadth is the primary product** | They close many feature gaps, but migration would discard the sovereign/fact-oriented core and introduce a larger runtime. |
| Replace hand-rolled auth with OIDC immediately | **Not for the first single-admin hardening step** | First fix credential leakage and throttling; add OIDC when multiple users or external identity is a real requirement. |
| Build a custom sanitizer | **No** | Use a maintained parser/allowlist sanitizer or render escaped text/Markdown. Security filters are a poor place for novelty. |
| Add Redis/distributed coordination now | **No** | Prove the single-node supervised and backup contract before paying multi-instance complexity. |
| Add an S3-compatible media adapter | **Yes, behind a small interface** | It is a local boundary with clear operational value and keeps development CAS simple. |
| Add incremental generation now | **Measure first** | A full build is simpler and likely adequate for the current catalog; add dependency tracking only after a measured bottleneck. |

## Deliberate non-goals

These are not gaps to close in the current release slice:

- Rebuilding a general-purpose plugin marketplace.
- Supporting multi-region active/active writes.
- Replacing AaronDB merely because PostgreSQL/Ecto are more familiar.
- Adding GraphQL before the content/API contract is stable.
- Claiming simulated IPFS pinning as a production feature.
- Calling local unit tests and one smoke run “production readiness.”

## Source register

Primary documentation used for comparison:

- [OTP supervisor](https://www.erlang.org/doc/apps/stdlib/supervisor.html) and [OTP application](https://www.erlang.org/doc/apps/kernel/application.html)
- [Plug](https://hexdocs.pm/plug/readme.html), [Phoenix Plug](https://phoenix.hexdocs.pm/phoenix/plug.html), [Phoenix deployment](https://phoenix.hexdocs.pm/deployment.html), [Phoenix/Ecto](https://phoenix.hexdocs.pm/ecto.html)
- [Payload collections](https://payloadcms.com/docs/configuration/collections), [Payload access control](https://payloadcms.com/docs/access-control/overview), [Payload drafts](https://payloadcms.com/docs/versions/drafts), [Payload database adapters](https://payloadcms.com/docs/database/overview)
- [Strapi REST API](https://docs.strapi.io/cms/api/rest), [Strapi Users & Permissions](https://docs.strapi.io/cms/features/users-permissions), [Strapi Draft & Publish](https://docs.strapi.io/cms/features/draft-and-publish), [Strapi Media Library](https://docs.strapi.io/cms/features/media-library), [Strapi deployment](https://docs.strapi.io/cms/deployment)
- [Eleventy incremental builds](https://www.11ty.dev/docs/usage/incremental/), [data cascade](https://www.11ty.dev/docs/data-cascade/), [collections](https://www.11ty.dev/docs/collections/)
- [SQLite transactions](https://sqlite.org/lang_transaction.html), [SQLite backup API](https://sqlite.org/backup.html), [SQLite WAL](https://www.sqlite.org/wal.html), [PostgreSQL WAL](https://www.postgresql.org/docs/18/wal-intro.html)
- [AWS S3 versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html), [S3 presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html), [MinIO versioning](https://docs.min.io/aistor/administration/objects-and-versioning/), [MinIO S3 compatibility](https://docs.min.io/aistor/developers/s3-api-compatibility/)
- [OWASP XSS prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet), [OWASP DOM XSS prevention](https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet)
- [Gemini structured output](https://ai.google.dev/gemini-api/docs/structured-output), [Gemini Generate Content API](https://ai.google.dev/api/generate-content)
- [Lustre SSR/hydration](https://lustre.hexdocs.pm/guide/05-server-side-rendering.html), [Lustre full-stack applications](https://lustre.hexdocs.pm/guide/06-full-stack-applications.html)
- [OpenID Connect Core](https://openid.net/specs/openid-connect-core-1_0.html)
- [GitHub Actions](https://docs.github.com/actions), [workflow syntax](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions), [deployment environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)

## Final assessment

**What is good:** the core data model is explicit, configuration is mostly loaded once, the project has live smoke/restore scripts, and the codebase is small enough for a focused hardening pass.

**What is not good enough:** authentication, output rendering, AI ingestion, lifecycle supervision, media durability, generation atomicity, schema evolution, and restore proof all sit below the bar set by mature alternatives. The project should not add distributed or plugin complexity until those edges are repaired.

**Rich Hickey certification:** keep the fact-oriented AaronDB core and the small `Theme` abstraction; reject incidental complexity. Add explicit data boundaries, typed results, and composable adapters where they reduce risk. Do not import a heavyweight CMS or distributed system to compensate for local boundary bugs.
