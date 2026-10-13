# Railway preparation for M00

This configuration runs the web application and a separate Solid Queue worker.
M00 remains open until its acceptance report passes. Hosting does not waive the
live evidence gate. No Railway service has been created or deployed by this change.

## Services

Use one Railway PostgreSQL service and two application services built from this
repository's Dockerfile. Select `/railway.web.json` as the web service's config
file and `/railway.worker.json` as the worker's config file. Keep one replica of
each and disable sleeping for the worker. Do not enable
`SOLID_QUEUE_IN_PUMA`, because `bin/jobs` runs the scheduler and workers separately.

The web pre-deploy command is `bin/rails db:prepare`. Deploy web first so all
databases are prepared before starting the worker. Web listens on Railway's
`PORT` and has `/up` as its health check. The worker has no HTTP health check or
public domain. Give web a Railway HTTPS domain.

## Variables

Set these on both application services:

| Variable | Value |
| --- | --- |
| `RAILS_ENV` | `production` |
| `RAILS_MASTER_KEY` | Existing master key, supplied privately through Railway variables |
| `DATABASE_URL` | Reference to PostgreSQL's private `DATABASE_URL` |
| `APP_HOST` | Web hostname, without scheme or trailing slash |
| `M00_DIAGNOSTICS` | `true` during the evidence window |
| `UNATTENDED_MONITORING` | `true` to keep analysis and alerts running without a login |

Keep the master key out of source control, commands, logs and screenshots.
The existing encrypted credentials supply the Twelve Data key and mail credentials.

The primary database is the database named by `DATABASE_URL`. The cache, queue
and cable connections use the same PostgreSQL host and credentials with database
names `fxtrack_production_cache`, `fxtrack_production_queue` and
`fxtrack_production_cable`. Rails `db:prepare` creates and loads their installed
schemas. The database role must have database-creation permission. If separate
connections are provided, set `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL` and
`CABLE_DATABASE_URL` on both application services. Never point these three URLs
at the primary database or at each other: their schema loads target separate databases.

With `M00_DIAGNOSTICS=true`, the recurring `MarketDataCollectionJob` collects all
seven pairs at H1/H4 without an owner session. `UNATTENDED_MONITORING=true`
also enables signal analysis, pair warm-up and alerts without an owner session.
It requires a provisioned owner and still respects strategy, enabled-pair,
freshness, sizing and notification rules. The web application remains protected
by login. Existing provider quota reservations, close scheduling,
deduplication and collection locking remain active. With the variable unset or
`false`, collection follows the normal pair selection. With
`UNATTENDED_MONITORING` also unset or `false`, the existing owner-session rule
applies to analysis and alert dispatch. Stop the worker to stop all monitoring.

## Preserve evidence and hand over collection

Complete this handoff only after deployment approval. Provision PostgreSQL
before the first application deploy, and stop local `bin/dev` or
`twelve_data:watch` before taking the final snapshot. Keep local collection
stopped after handoff: separate databases cannot coordinate the same provider quota.

Create a private backup in the ignored local `tmp` directory:

```sh
mkdir -p tmp
pg_dump --format=custom --no-owner --no-acl --file=tmp/railway-handoff.dump fxtrack_development
chmod 600 tmp/railway-handoff.dump
```

This contains the full application database, including owner, journal and session
data as well as M00 evidence. Restore only into a confirmed empty destination
primary database, before starting the web application or worker. Use a private
PostgreSQL connection or a temporary Railway TCP proxy and a protected libpq
service/password file. Do not paste a database password into a shell command.

```sh
pg_restore --dbname='service=fxtrack_railway' --no-owner --no-acl --exit-on-error --single-transaction tmp/railway-handoff.dump
```

Do not use `--clean` against a populated destination. Do not overwrite a live
database. Confirm the destination and record row counts for `provider_requests`,
`data_quality_metrics` and `candles` before and after restore. Preserve IDs,
timestamps and sequences. Then run `bin/rails db:prepare` remotely to apply any
new primary migrations and prepare the three auxiliary databases. Do not import
development jobs into the production queue database.

Invalidate copied browser sessions before opening the remote app to the owner
(`Session.delete_all` in the remote Rails console); this does not erase evidence.
Log in again through HTTPS. Start the single worker only after restore and
database preparation succeed. Stop local collection for the whole Railway run.

## Observe and stop

Use a Railway service shell to run these read-only database reports:

```sh
bin/rails twelve_data:report
bin/rails twelve_data:acceptance
```

Check Railway worker logs for successful recurring jobs and failed jobs. Confirm
new provider requests and quality metrics appear after expected candle closes,
all fourteen combinations stay fresh, and quota remains within budget. A worker
process starting successfully does not prove M00 acceptance.

When M00 passes, stop the worker, unset `M00_DIAGNOSTICS` on both services and
review the transition to selected-pair monitoring before restarting it. Keep
`UNATTENDED_MONITORING=true` for the approved unattended analysis and alerts. The
existing `collect_all_pairs` setting also needs to be changed to `false` after
the gate so later monitoring respects enabled pairs. This change does not mark
M00 complete or perform that transition automatically.

## Preparation evidence

Verified locally on 2026-10-14 (Auckland): `bin/ci` passed 242 examples, lint and
all configured security checks; production assets compiled; the Docker image
built successfully. A disposable PostgreSQL 16 container proved all four
production databases prepare successfully, web `/up` returns HTTP 200, and
Solid Queue registers its worker, dispatcher and scheduler. That smoke check
used both monitoring flags off and made zero provider requests; the RSpec suite
proves unattended collection, analysis and email dispatch with stubbed delivery.
Temporary containers, volumes and network were removed after the check.

Railway credentials, destination project, database restore and live worker
operation are deployment steps, not claims established by local tests. No Git
remote is configured in this checkout yet; the owner will push to GitHub.

References: [Railway Rails guide](https://docs.railway.com/guides/rails) and
[Railway config as code](https://docs.railway.com/config-as-code/reference).
