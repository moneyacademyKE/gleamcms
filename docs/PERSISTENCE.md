# GleamCMS persistence, backup, and restore

## Authoritative data

AaronDB/Mnesia facts are authoritative. The configured `GLEAMCMS_DATA_DIR` holds
that state and must live outside the release checkout. Generated HTML/RSS under
`GLEAMCMS_OUTPUT_DIR` is a rebuildable projection, not the source of truth.
`legacy_posts.json` is an import input only and is never imported unless
`GLEAMCMS_IMPORT_LEGACY=true` is explicitly set.

## Backup contract

Back up the complete `GLEAMCMS_DATA_DIR` directory as one consistent unit while
the process is stopped or quiesced by the supervisor. Include `schema.DAT`,
`datoms.DCD`, `LATEST.LOG`, and any other Mnesia files. Encrypt backups at rest,
store them outside the host, retain daily backups for 30 days and monthly
backups for 12 months, and periodically test that the backup can be read.
These retention and encryption duties belong to the deployment operator.

Generated output can be rebuilt after restore by starting the application and
calling the authenticated generation endpoint. Backing it up is optional and
should not replace backing up the data directory.

## Manual backup

Set the source and destination to deployment-managed paths. Do not use a
wildcard that could mix data directories or copy a live directory mid-write.

```sh
# Stop or quiesce GleamCMS first.
tar -czf /secure/backups/gleamcms-data-$(date -u +%Y%m%dT%H%M%SZ).tar.gz \
  -C "$(dirname "$GLEAMCMS_DATA_DIR")" "$(basename "$GLEAMCMS_DATA_DIR")"
```

The archive must be encrypted by the operator's backup system before leaving
the host. Never commit it or place it under the repository.

## Restore procedure

1. Stop GleamCMS and preserve the failed data directory for investigation.
2. Extract the selected archive into a new isolated directory.
3. Start GleamCMS with that directory as `GLEAMCMS_DATA_DIR`, a disposable
   output directory, and `GLEAMCMS_IMPORT_LEGACY=false`.
4. Run `scripts/smoke_test.sh` or equivalent authenticated health/read/generate
   checks against the isolated instance.
5. Compare expected post counts/content and record the archive timestamp as the
   recovery point.
6. Only after the isolated check passes, schedule the production cutover to the
   restored directory and rebuild generated output.

## Restore drill evidence

The application has been verified to boot with an isolated data directory and
create Mnesia files (`datoms.DCD`, `LATEST.LOG`, `schema.DAT`). A complete
archive extraction and authenticated data restore drill remains a release
operator action; it must record:

- **RPO:** timestamp of the selected backup and newest accepted fact.
- **RTO:** elapsed time from stopping the failed process to passing the smoke
  test after restore.
- Archive checksum, source/destination paths, post-count comparison, and
  operator sign-off.

Do not claim production resilience until that evidence is attached to the
release witness.
