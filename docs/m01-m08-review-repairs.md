# M01-M08 review repairs

Authorized by the owner on 2026-10-12. Work branch:
`fix/m01-m08-review-findings`. M00 continues collecting live evidence and its
active spec is preserved.

- F-01: Current H4 evidence is required before a qualifying setup becomes a
  trade signal; stale, missing, rejected or failing H4 produces WAIT.
- F-02: Session eligibility is checked after collection, at the engine entry,
  before each analysis and before persisting the run/signal. Disabled pairs are
  locked again at persistence. An eligible session is locked through the
  run/signal transaction so revocation and persistence have a defined order.
  Dispatch checks remain.
- F-03: Alert sends serialize on their delivery row and use the owner-approved
  Resend HTTPS API with frozen payloads and provider idempotency keys. No real
  email is sent by automated tests. The retry window is bounded to 24 hours.
- F-04: Ledger creation locks the shared account within the save transaction,
  before balance validation and insertion. Concurrent withdrawals cannot both
  spend the same available balance.
- F-05: Clone names reserve space for their unique suffix within the existing
  80-character limit.

Regression coverage includes stale H4, revoked sessions, concurrent withdrawals,
simultaneous alert workers, frozen HTTP retries, provider error classifications,
expired retry windows and maximum-length clone names. The email schema change
adds only nullable payload/timestamp columns; no existing data is removed.

## Migration ordering repair

F-06: Renamed the retry migration from version `20261012020000` to
`20261012140000`, after `20261012130000` creates the delivery table. Updated
the schema version. Local development and test databases already had the
columns, so only their `schema_migrations` version records were reconciled,
after checking the columns exist and the new version was not already recorded.
No application data or columns were dropped or recreated.

Fresh replay in a uniquely named disposable PostgreSQL database passed all
17 migrations and confirmed both retry columns. That disposable database was
removed afterward. Another database that applied the old version needs the same
metadata reconciliation before running the renamed migration.
