# GleamCMS production promotion checklist

This checklist is the release gate. A green build alone is not production
readiness.

## Before promotion

- [ ] Record the exact source revision and clean working-tree status.
- [ ] Record Gleam, Erlang/OTP, and dependency lock versions.
- [ ] Run `gleam deps download`, `gleam format --check`, `gleam build`, and
      `gleam test`.
- [ ] Run the live HTTP smoke test with disposable or staging-only credentials.
- [ ] Confirm production `GLEAMCMS_SECRET`, `GLEAMCMS_ADMIN_TOKEN`,
      `GLEAMCMS_DATA_DIR`, and `GLEAMCMS_OUTPUT_DIR` are supplied by the secret
      store/deployment environment, not committed files.
- [ ] Confirm `GLEAMCMS_IMPORT_LEGACY=false` unless an explicit import is being
      performed and reviewed.
- [ ] Complete the backup/restore drill and record RPO/RTO evidence.
- [ ] Review `docs/THREAT_MODEL.md` and confirm deferred controls are accepted.
- [ ] Confirm staging smoke test, TLS edge, process supervision, disk alerts,
      and operator ownership.

## Promotion

1. Deploy the exact artifact/source revision that passed CI and staging.
2. Keep the previous artifact and configuration available for rollback.
3. Start with the production data directory; never copy staging data over it.
4. Verify startup logs contain no secrets and show the expected safe paths.
5. Verify `GET /health`, login, an authenticated read, and generated output.
6. Record the release witness and obtain operator sign-off.

## Rollback

1. Stop the current process gracefully.
2. Restore the previous application artifact and compatible configuration.
3. Preserve the current data directory; do not delete or reset Mnesia files.
4. Start the previous artifact against the same data directory.
5. Verify `/health`, authenticated reads, and representative generated output.
6. If data compatibility is in doubt, restore the backup into an isolated
   directory first and run the smoke test before touching production.
7. Record the rollback revision, reason, recovery point, and recovery time.

## Production classification

The application is **not production-ready** until this checklist, the restore
dril, CI/staging evidence, and operator sign-off are complete. Rate limiting,
richer metrics, multi-instance coordination, and product features remain
post-release work and must not be smuggled into this release gate.
