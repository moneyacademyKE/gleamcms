# Restore drill record

- Date: 2026-08-14 UTC
- Scope: isolated local Mnesia fixture and archive extraction
- Data directory: `.smoke/restore-final3-10657/data`
- Archive: `.smoke/restore-final3-10657/data.tar.gz`
- Archive SHA-256: `dab6e811b83512fecb65042d0c550a7aac5e773d08684687863e7b1bc3a4f23d`
- Verified restored files: `datoms.DCD`, `schema.DAT`, `LATEST.LOG`
- RPO: fixture creation timestamp in `.smoke/restore-final3-10657/fixture.log`
- RTO: archive extraction and file verification completed in the same local run; exact wall-clock timing remains operator-owned for production.
- Production status: this proves archive integrity and isolated extraction only. It does not replace a production backup service, encrypted retention, or operator sign-off.
