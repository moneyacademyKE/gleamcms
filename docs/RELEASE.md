# GleamCMS release provenance

## Canonical source

The canonical working copy for this release baseline is currently local:

- Path: `~/Desktop/gleamcms`
- Git remote: none configured
- Default branch: `main`
- Repository status: local-only until a remote is explicitly selected

The existing `moneyacademyKE/cms` repository is a separate TypeScript/Cloudflare project and is not the canonical home for GleamCMS. A hosted remote must be chosen before any push or shared release workflow.

## Baseline contents

Tracked source includes:

- `src/` Gleam and Erlang application code
- `test/` automated tests
- `priv/static/editor.js` runtime static asset
- `gleam.toml` and `manifest.toml` dependency declarations and lock state
- `README.md` configuration and project documentation

Generated build output, local AaronDB/Mnesia data, generated sites, editor secrets, and OS/editor noise are intentionally excluded by `.gitignore`.

## Reproducibility check

From a clean checkout or copy of the tracked tree:

1. Install Gleam 1.17.0 and Erlang/OTP 29 (the versions used for this baseline).
2. Run `gleam deps download`.
3. Run `gleam format --check`.
4. Run `gleam build`.
5. Run `gleam test`.

The live HTTP smoke test and deployment evidence remain release-gate work in later roadmap steps.

## Release status

This is a provenance baseline, not a production release. No hosted remote, staging environment, production credentials, or production promotion is configured by this document.
