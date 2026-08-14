# GleamCMS operations runbook

## Service contract

- **Liveness:** `GET /health` returns HTTP 200 only after AaronDB has started and
  the process can query it. A non-200 response means restart or investigate the
  process; do not route traffic to it.
- **Readiness:** the current single-process service has no separate readiness
  endpoint. Treat `/health` as readiness for this deployment shape. Add a
  distinct readiness probe before introducing background migrations or multiple
  dependencies.
- **Public output:** generated files are served below
  `/gleamcms_output/<theme>/`. They can be rebuilt from authoritative post facts;
  output is not the source of truth.

## Logs

The process emits Wisp request logs (`status method path`) and application logs
for startup configuration, imports, saves, publishes, generation totals, and
failures. Secrets and admin tokens must never appear in log arguments or shell
commands. HTTP request bodies and cookies are not logged.

Recommended deployment handling:

- Send stdout/stderr to the supervisor's journal or a managed log sink.
- Retain searchable application logs for 30 days and security/audit events for
  90 days, subject to the operator's privacy policy.
- Alert on three consecutive failed health checks, process restarts, startup
  configuration errors, generation errors, or repeated 4xx/5xx spikes.
- Alert on disk usage above 70%; page an operator above 85%.

## Supervision and limits

Run one GleamCMS process under a supervisor with automatic restart and a bounded
restart policy. Put the HTTP listener behind TLS termination and a proxy with
connection/request timeouts. Set OS/container limits for memory, open files,
CPU, and disk; the application rejects request bodies above 1 MiB.

Shutdown is supervisor-driven: send SIGTERM, allow the process to drain, then
start the same artifact with the same data and output directories. Never delete
Mnesia data to resolve a boot problem.

## Common failures

| Symptom | First check | Action |
|---|---|---|
| Process exits at boot | Configuration error log | Set non-blank secrets and valid paths/port; do not log values. |
| `/health` fails | Process log and data directory permissions | Verify `GLEAMCMS_DATA_DIR` exists and is writable, then restart. |
| Admin redirects to login | Cookie, hostname, TLS edge, and Origin/Referer | Re-authenticate; verify the edge preserves the public host and HTTPS. |
| Generation returns errors | Output directory permissions and free disk | Fix storage, then regenerate; source facts remain authoritative. |
| Data appears missing | Data directory and node identity | Stop the process and verify the configured directory before any restore. |

## Imports and migrations

`GLEAMCMS_IMPORT_LEGACY=false` is the production default. Set it to `true` only
for an explicit, reviewed import of `legacy_posts.json`, capture the count and
errors, then return it to `false`. There is no automatic schema migration in
this release; a future migration must be a separately tested, reversible
operation with a backup before execution.

## Operator checklist

1. Check `/health` and recent logs.
2. Confirm the process, data directory, output directory, and free disk.
3. Take or verify a backup before repair or restore.
4. Restore only into an isolated directory first, then run the smoke test.
5. Record the incident, recovery point, recovery time, and follow-up action.
