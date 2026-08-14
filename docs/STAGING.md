# Staging runbook

Staging is a separate deployment, not a production-shaped local directory.
Use a distinct hostname, credentials, `GLEAMCMS_DATA_DIR`, and
`GLEAMCMS_OUTPUT_DIR`. Never reuse production data or secrets.

## Required staging environment

```text
GLEAMCMS_SECRET=<staging-only random secret>
GLEAMCMS_ADMIN_TOKEN=<staging-only random token>
GLEAMCMS_DATA_DIR=/var/lib/gleamcms-staging/data
GLEAMCMS_OUTPUT_DIR=/var/lib/gleamcms-staging/output
GLEAMCMS_PORT=4000
GLEAMCMS_COOKIE_MAX_AGE=3600
GLEAMCMS_IMPORT_LEGACY=false
```

The edge terminates TLS and forwards requests to the local GleamCMS listener.
The edge must provide the public hostname, HTTPS redirect, HSTS after HTTPS is
mandatory, and process supervision. GleamCMS itself must not contain those
provider-specific credentials or service definitions.

## Promotion gate

1. CI passes dependency download, formatting, build, unit/security tests, and
   the live HTTP smoke test.
2. Deploy the same built source/dependency lock state to staging.
3. Run `scripts/smoke_test.sh` against staging using staging-only credentials
   and an isolated staging output/data location.
4. Review logs for startup, health, authentication, generated output, and
   restart evidence.
5. Promote only after the persistence restore drill and rollback evidence are
   attached to the release record.

## Rollback

Keep the previous application artifact available. Stop the current process,
restore the previous artifact/configuration, and restart against the same
staging or production data directory. Do not roll back by deleting Mnesia data.
Run `/health` and the smoke test after rollback.

## Secrets

Secrets belong in the deployment platform's secret store. `.env` files and
real credentials are local-only and are excluded by `.gitignore`.
