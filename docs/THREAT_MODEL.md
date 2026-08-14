# GleamCMS web threat model

## Scope

This baseline covers the Mist/Wisp HTTP process, the cookie-authenticated admin
surface, generated HTML output, and the browser editor. It assumes TLS is
terminated by the deployment edge when GleamCMS is not directly serving HTTPS.

## Assets

- The admin token and session-signing secret.
- Draft and published post content, including generated files.
- The AaronDB process and its local Mnesia data.

## Controls in this baseline

- Configuration fails closed when either admin credential is blank.
- State-changing requests use Wisp's known-header CSRF protection; requests
  without an Origin/Referer lose cookie authentication, and mismatches fail.
- Session cookies are HttpOnly, SameSite=Strict, and bounded by Max-Age.
- Request bodies are capped at 1 MiB before handlers read them.
- Responses include security headers for framing, MIME sniffing, referrer
  leakage, permissions, and a restrictive baseline CSP.
- Post slugs are validated before persistence and post HTML is sanitized before
  storage. Generated output is served beneath the configured output directory.
- The live smoke test exercises unauthorized access, authentication, mutation,
  sanitization, generated output, and restart behavior.

## Deferred controls

- Login rate limiting and account lockout are deferred until a deployment-level
  client/IP identity and shared limiter store are selected. The current
  single-process implementation must not pretend an in-memory limiter protects
  a multi-instance deployment.
- A per-form CSRF token is deferred because known-header protection plus
  SameSite=Strict is the current browser boundary; add tokens if cross-origin
  admin workflows become a requirement.
- HSTS is deferred to the TLS-terminating edge. It must be enabled only after
  HTTPS is mandatory for the public hostname.
- Secret rotation and audit logging are deferred to the persistence and
  observability roadmap tasks.

## Release decision

This is a stronger local/staging boundary, not proof of production safety by
itself. Production still requires TLS edge configuration, backup/restore proof,
CI gates, and an operational rollback path.
