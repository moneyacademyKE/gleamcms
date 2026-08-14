# Learnings and Architectural Patterns: GleamCMS

## 1. Rich Hickey's Simplicity Invariants (*Simple Made Easy*)

### Uncomplecting Orthogonal Concerns
- **Problem:** When an HTTP module handles routing, authentication, parsing, business logic, file serving, and security headers, it complects several lifecycles.
- **Pattern:** Deconstruct into single-responsibility boundaries:
  - `auth`: Pure validation of session state and credentials.
  - `static`: Serving immutable assets and applying declarative headers.
  - `api`: Serialization, decoders, and AaronDB transaction orchestration.
  - `router`: Pure deterministic dispatch tree.

### Fact-Oriented Information Modeling
- In GleamCMS, posts are not opaque rows; they are immutable Datalog facts `[entity, attribute, value]`.
- Section composition on a landing page is simply a collection of posts linked by entity ID and partitioned by `section_type`.
- Rendering is a pure transformation `f(Facts, ThemeConfig) -> HTML`.

## 2. Line of Code (LOC) Constraint Enforcement
- **Invariant:** All source files must remain strictly `< 500 LOC`.
- **Pattern for Large Catalogs/Datasets:** Never place large static lists in a single file. Partition datasets into semantic catalogs (`catalog_a.gleam`, `catalog_b.gleam`) and expose a unified aggregator in `library.gleam`.
- **Pattern for HTTP Routers:** A router should never contain inline HTML templates or JSON decoders. Keep routing files under 100 LOC by delegating to dedicated submodules.

## 3. Runtime & FFI Boundary Isolation
- Host-level Erlang FFI calls (`@external(erlang, ...)`) should be quarantined inside a dedicated `gleamcms/runtime/` boundary (`ffi.gleam`).
- Higher-level modules (`config.gleam`, `designer.gleam`, `gleamcms.gleam`) consume typed Gleam interfaces rather than defining duplicate external bindings.

## 4. Red/Green TDD & Verification Discipline
- Always accompany structural refactoring with domain-specific unit tests (`auth_test.gleam`, `themes_test.gleam`).
- Validate fail-closed security properties and deterministic hashing.

## 5. Atomic Projection Pattern (Nix/Hickey Principle)
- Projections (such as generated static websites) must never be mutated in-place where readers can observe partial or crashed builds.
- Always build into an isolated staging directory (`<output>.staging`), verify all write results (`simplifile.write`), and execute an atomic directory swap (`simplifile.rename`).
- Upon any write error, clean up the staging directory and propagate the error report.

## 6. Secure Credential Boundaries
- Never accept authentication tokens in URL query strings (`?token=...`), which leak to server access logs, proxy logs, and `Referer` headers.
- Enforce explicit `POST` payload submissions and issue signed HMAC session cookies (`HttpOnly`, `SameSite=Strict`).

## 7. AST-Driven Content Parsing over Regex Heuristics
- Regular expressions cannot safely parse or sanitize hierarchical HTML.
- Deconstruct input into an Abstract Syntax Tree (`Inline`, `Block`, `Document`).
- Perform context-safe encoding at the projection leaf nodes (entity escaping, URL scheme whitelisting).

## 8. Bounded Subprocess Execution
- Never spawn external OS ports/subprocesses without bounded receive timeouts.
- Implement explicit receive timeouts (`after 30000 -> ...`) with process cleanup (`port_close`) to prevent hung zombie processes.

## 9. Pluggable Storage Abstractions
- Abstract Content-Addressed Storage (CAS) behind an immutable value interface (`StorageAdapter`).
- Validate incoming file extensions against a strict whitelist before computing SHA-256 digests.
