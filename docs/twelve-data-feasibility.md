# Twelve Data feasibility evidence

Status as of 2026-10-12 (Auckland): M00 remains open. All fourteen history
windows have been measured and repeated with zero recorded fingerprint
mismatches. Candle persistence is active under the owner's retention decision.
The 48 cumulative live trading-hour window and live reproducibility/freshness
evidence remain incomplete. Earlier sections below retain the chronological
implementation evidence and superseded blockers.

## Verified documentation

Reviewed on 2026-10-12. The owner supplied the forex_pairs contract: a catalogue
with symbol, currency_group, currency_base and currency_quote; one credit per
request. Catalogue inclusion does not establish time_series access.

[Credit documentation](https://support.twelvedata.com/en/articles/5615854-credits)
documents one-credit time_series requests per symbol, minute resets, a Basic
800-credit daily reset at midnight UTC and api-credits-used/api-credits-left
response headers. These are documentation evidence, not measurements of this
key or available shared-account headroom. The owner-provided dashboard screenshot confirms Basic 8 with an API
minute maximum of 8 and a daily allowance of 800; it shows zero usage at
capture. Remaining capacity must still be checked during each live run. Never record the key here.

[Timezones](https://support.twelvedata.com/en/articles/5745849-timezones)
describes a forex default of Australia/Sydney. Request explicit UTC for H1/H4
and validate metadata and timestamps; do not infer the default timezone.
[API documentation](https://twelvedata.com/docs) must be checked for exact
time_series fields, interval names and bar-open semantics before client work.

[Personal-use guidance](https://support.twelvedata.com/en/articles/5332349-commercial-and-personal-usage)
permits personal/internal uses on individual plans and prohibits redistribution
and commercial third-party display.
[Terms section 16](https://twelvedata.com/terms) makes retention subject to the
subscription and provider restrictions. This does not establish a retention
duration for this account. Historical price storage was blocked until reviewed; see the owner decision
under Retention-rights review. Sanitized diagnostic metrics
will exclude prices, raw responses and secrets.

## Account evidence

The owner supplied a dashboard screenshot and explicitly instructed its use.
It shows Basic 8, API credits used 0/800, minutely average 0/8 and minutely
maximum 0/8. These establish account-specific REST allowances of 8 per minute
and 800 per day at capture. The WebSocket figures are separate and are not
REST capacity. This screenshot does not establish historical-storage rights,
continuous absence of other consumers, or a completed observation window.

## Pending acceptance evidence

- Other consumers of the key and measured reserved headroom during the probe.
- Applicable retention permission and duration.
- All seven pairs at H1/H4, closed-candle reproducibility and historical depth.
- Freshness/gaps, weekend closure evidence and quote/spread limitations.
- Measured credits, bounded retry/timeout/429 evidence and redaction checks.
- History windows for every pair/interval, a repeated-fetch revision check and
  at least 48 hours of live trading-day collection (see Acceptance window).

## Current local checks

### Quote and spread measurement, 2026-10-12 (Auckland)

One quota-reserved EUR/USD H1 probe succeeded. Its candle entries contained
only `datetime`, `open`, `high`, `low` and `close`; no bid, ask or spread fields
were present. No raw prices, response body or credentials were recorded here.
This measures that response only, not all provider products or endpoints.
OHLC feed prices do not establish an executable broker quote, spread or fill.
Treat the feed as indicative decision-support data; broker-specific execution
and composite-feed differences remain outside this candle evidence.

### Automated checks, 2026-10-12 (Auckland)

The resumed M00 changes passed `bin/ci`: 172 RSpec examples, RuboCop and all
configured security checks. Fixture tests cover malformed response bodies,
sanitized transport/HTTP failures and candle ordering/window validation.
Automated checks do not replace the required live collection window.

RSpec Rails tests: bundle exec rspec. Uses the isolated fxtrack_test database.
Provider responses will be stubbed; automated tests must not use the real key.
Operator probe/report tasks exist. No public provider endpoint is introduced.

## Metrics contract

ProviderRequest stores supported symbol, interval, fixed endpoint, UTC request
time, enumerated status/error code, optional HTTP status and optional measured
credit headers. Nil credit usage means unknown, never zero. DataQualityMetric
records one evaluation per request, UTC coverage timestamps, nonnegative counts
and freshness. Neither table stores prices, response text, URLs or credentials.
CandleFingerprint stores one keyed HMAC-SHA256 digest per closed candle
(symbol, interval, UTC open time), not the prices themselves.

Gitleaks scans Git with --no-textconv: Rails' credential textconv decrypts
encrypted blobs for human display, which is inappropriate for a committed-byte
scan. The ciphertext format was checked without printing its contents.

## Operator commands

```sh
bin/rails 'twelve_data:probe[EUR/USD,1h]'
bin/rails twelve_data:report
```

Each explicit probe runs a single pair/interval, requests eight observations with
explicit UTC and ascending ordering, and stores only sanitized metrics. Use only
1h or 4h and one of the seven supported symbols. The client uses the documented
Authorization header, never a credential in the URL. Missing credentials fail
without printing the value. A failure exits nonzero. Report always declares the
acceptance gate pending; request counts do not imply seven days of usable data.

The diagnostic quota policy uses 7 requests/credits per minute and 720 per UTC
day, retaining one minute credit and 80 daily credits below the confirmed Basic
8 limits. Reservations use a PostgreSQL transaction advisory lock shared by
all probe processes. Each attempt reserves one documented endpoint credit; crashed reservations
still consume local budget. The credits_used column retains the raw cumulative
minute header, not a per-request cost. It must not be summed across requests. Response credit headers are recorded when numeric. Cumulative remote minute
usage and in-flight local reservations protect headroom; a low minute balance
pauses further requests.
This cannot coordinate independent applications sharing the same key; their
consumption must be accounted for before unattended observation. No paid
upgrade is performed.

There are at most three attempts per explicit probe, with 5-second connect/write
and 10-second read timeouts. HTTP internal retries are disabled. Timeout,
transport failures, 429 and HTTP 5xx can retry with bounded backoff. Numeric
Retry-After above 60 seconds causes a stop, not a long sleeping process.
Unknown or nonnumeric credit headers remain nil. Provider response bodies,
prices and exception messages are not persisted in metrics. No candle price
table exists while storage rights are unresolved.

## Outstanding implementation and observation gates

This is a diagnostic foundation, not a completed M00 implementation. The explicit collection task implements close-aligned due selection from observed
closed timestamps and validates catalogue symbols separately. Cross-request
candle reproducibility is checked through keyed fingerprints. Weekend closure
follows the owner-selected New York 17:00 rule described under Closure update;
it is a convention, not provider-confirmed session data. The seven-day run must
still observe at least one weekend under that rule. Historical retention
rights also remain unresolved. Do not mark M00 complete or enable production
monitoring based on these fixtures.

Local foundation verification: 32 RSpec examples passed on 2026-10-12; fixture
requests consumed no provider credits. Git secret scanning passed with Rails
textconv disabled. GitHub workflow execution has not been observed remotely.

## Live connection blocker

On 2026-10-12 (Pacific/Auckland), one bounded EUR/USD H1 task recorded three
transport_error attempts with no HTTP status or credit headers. Credit usage is
unknown. An additional isolated client diagnostic identified OpenSSL::SSL::SSLError;
a credential-free Rails request reproduced certificate verification failure:
`unable to get certificate CRL`. A standalone Ruby credential-free request reached
the provider, so the failure is specific to the Rails-loaded TLS environment.
Rails confirmed credential presence without printing the key. No certificate
verification bypass was applied. Repair the local TLS trust/CRL configuration
before collecting live evidence; do not infer provider access or price quality
from this failure. The diagnostic client call was outside persisted probe metrics
and also failed before an HTTP response.

TLS repair verified on 2026-10-12 (Pacific/Auckland): Bundler previously loaded
Ruby OpenSSL 3.3.0 while standalone Ruby loaded 4.0.2. The older library sets
CRL_CHECK_ALL in its default trust store and fails against the local OpenSSL
3.6.0 environment. Gemfile now requires openssl ~> 4.0 and Gemfile.lock selects
4.0.2. No certificate-verification override or TLS initializer was added.
The bounded live EUR/USD H1 probe returned HTTP 200 with success status and
one measured credit. Full bin/ci passed with 32 RSpec examples and all security
checks. The historical TLS blocker is resolved; M00's other unchecked criteria,
including seven-day evidence and retention rights, remain pending.
Reference: https://github.com/ruby/openssl/issues/952

## Collection update

Run `bin/rails twelve_data:collect` for one bounded cycle. It orders pairs by
oldest request so quota pauses do not starve later combinations. Repeat on the
next minute to continue coverage. Successful H1/H4 requests are due only after
their observed next close plus a 60-second publication grace period. H4 is not
fetched every hour. Overlapping collection processes return already_running;
a session advisory lock is released in ensure. No scheduler or background
production worker was enabled. Stop collection by ceasing task invocations;
resume uses persisted request/evaluation evidence. Do not infer market closure
from absent data. Collection failures remain observable and M00 cannot pass
until the observation window is verified.

`bin/rails 'twelve_data:catalogue[EUR/USD]'` validates a single catalogue symbol
with the same retry/quota controls. Catalogue records have no candle interval
and do not contribute candle coverage. On 2026-10-11 GBP/USD, USD/JPY, USD/CHF,
USD/CAD, AUD/USD and NZD/USD were also validated live, so all seven configured
symbols are confirmed in the catalogue. Catalogue responses carried no credit
headers; their cost is recorded as unknown.
A live EUR/USD catalogue request succeeded, with credit headers absent (unknown).
Live NZD/USD H4, EUR/USD H4 and GBP/USD H1 requests succeeded. Their usage headers
were 1, 2 and 3 with remaining values 7, 6 and 5, establishing cumulative minute
usage. Accounting now reserves documented one-credit requests and preserves raw
headers separately instead of incorrectly summing cumulative usage. The report
labels these as latest_minute_credits_used, not measured request credit totals.

Verification: 39 RSpec examples cover catalogue rejection, due selection,
partial failure, cumulative credit accounting and concurrent PostgreSQL quota
reservations. This does not yet prove all-seven live coverage, complete candle
reproducibility, weekend closure handling or seven days of evidence.

## Reproducibility update

Each successful time_series evaluation fingerprints its closed candles with
HMAC-SHA256 over the UTC open time and decimal OHLC values. Trailing zeros are
normalized, so "1.10" and "1.1" match. The key derives from the Rails
secret_key_base, so the digests cannot be reversed into prices by guessing
plausible values. Rotating secret_key_base makes existing fingerprints
incomparable; clear candle_fingerprints after rotation rather than reading the
resulting mismatches as provider defects.

The first digest seen for a symbol, interval and open time becomes the
reference. Later overlapping requests increment reproduced_count when they
match. Any difference sets the metric status to unreproducible, increments
mismatch_count and marks the request invalid_data. New digests from a
contradicting response are rolled back so they never become references. The
unique index serializes concurrent probes on the same candle. The report task
includes both counts.

Verification: 43 RSpec examples, adding overlap reproduction, mismatch
rejection without digest replacement, keyed digests and decimal normalization.
No live reproducibility evidence has been collected yet; that requires
collection cycles separated by at least one close.

## Closure update

Twelve Data documents no forex session: market_state and exchange_schedule
cover stock exchanges. A live EUR/USD H1 request on Sunday 2026-10-11 returned
candles from 09:00 to 16:00 UTC, each with a nonzero high/low range, and H4
responses ran continuously from Saturday 12:00 UTC. The provider therefore
publishes moving weekend prices outside the conventional interbank week.

The owner selected the New York 17:00 convention: the market is closed from
Friday 17:00 to Sunday 17:00 America/New_York (21:00 to 21:00 UTC in daylight
saving, 22:00 to 22:00 UTC in standard time). A candle is a closure candle when
it opens inside that window. Closure candles:

- are counted in closure_count, not closed_count;
- are excluded from gap, freshness and latest_closed_at calculations;
- never become reproducibility fingerprints.

Freshness compares the latest trading candle with the most recent trading
candle that should have closed, skipping the weekend. During the window,
current data reports the closed status. A response holding only closure
candles reports closed when it starts after the last expected trading candle,
and stale otherwise. With outputsize 8, H4 responses early on Monday can hold
only weekend candles, so closed may appear shortly after the reopen. Closed
evaluations count as successful requests.

Collection schedules the next request after the next trading candle closes, so
no requests are made over the weekend. Market holidays (for example 25 December
and 1 January) are not modelled and will surface as stale or gaps.

Fingerprints collected on 2026-10-11 before this rule cover weekend candles
only. They are never compared against trading candles, so they are inert.

Verification: 54 RSpec examples, adding daylight and standard time boundaries,
Friday close, missing final Friday candle, weekend gap suppression, weekend-only
responses and weekend collection scheduling. Live trading-hours reproducibility
evidence is scheduled after the 2026-10-11 21:00 UTC reopen.

## Historical depth update

`bin/rails twelve_data:history` measures each pair and interval at most once per
UTC day. It records two requests per combination, each one documented credit:

- `earliest_timestamp`: the provider's earliest available candle, stored as the
  metric's earliest_opened_at. Its documented body has no status field, so only
  an explicit error status fails.
- `time_series_history`: a 5000-candle time_series window (body limit 1 MB),
  evaluated with the normal quality rules. Gaps are accepted as measured
  evidence because long windows span holidays. Closed trading candles are
  fingerprinted; no prices are stored.

Collection ignores both endpoints. Invalid data is final for the day; only
provider failures are retried on the next run. The report task prints one
history line per combination.

Live results on 2026-10-11:

| Measure | H1 (all seven pairs) | H4 (six pairs) |
| --- | --- | --- |
| Provider earliest timestamp | 2020-01-29 to 2020-01-30 | 2020-01-29 to 2020-01-30 |
| 5000-candle window starts | 2026-03-17 08:00 UTC | 2023-11-23 to 2023-11-30 |
| Window span | 206.5 days | about 1045 to 1052 days |
| Trading candles | 3565 | 4441 to 4470 |
| Weekend candles | 1434 | 529 to 558 |
| Missing trading slots | 0 | 41 to 45 |
| Duplicates / mismatches | 0 / 0 | 0 / 0 |

Weekend candles make up about 29% of an H1 window, so 5000 H1 candles cover
only about 30 trading weeks. Deeper warm-up needs paged requests using
start_date/end_date, one credit each.

A GBP/USD H4 diagnostic (dates only) located all 43 missing slots:

- Holidays: 24 and 25 December and 31 December/1 January each year.
- Friday 20:00 UTC every week from December 2023 to February 2024. That slot
  opens at 15:00 New York standard time and is present in later winters, so
  this is a gap in the provider's older history.
- A 21:00 UTC slot on the first Sunday of October in 2024, 2025 and 2026. It
  is off the normal four-hour grid, which suggests a brief provider H4
  alignment shift. That date coincides with the start of Australian and New
  Zealand daylight saving; the cause is unconfirmed.

EUR/USD H4 is invalid. Its window contains three candles that break OHLC
consistency: 2024-11-28 08:00 UTC (low above open or close), 2024-11-28 12:00
UTC (high below open or close) and 2025-01-14 12:00 UTC (high below open or
close). At measurement time the evaluator rejected the whole window, so no
EUR/USD H4 depth figures were recorded.

Owner decision (2026-10-11 UTC): candles that fail validation are dropped and
counted in invalid_count. Their slots then appear as gaps, they are never
fingerprinted and must never be stored. Window-level contradictions (wrong
metadata, future or unsorted timestamps, contradictory duplicates) and windows
where every candle is invalid still reject the whole response. The 23:10 UTC
revision check re-measures EUR/USD H4 under this rule.

Cost note: the first history run re-requested failing windows every minute.
Two defects caused this. Legacy metrics recorded before the closure rule ended
on Sunday weekend candles, and the regression check treated them as later
trading closes. Separately, only successes stopped a rerun. About 28 credits
were spent on repeats. The regression check now ignores weekend closes, and
invalid data stops reruns. Requests on 2026-10-11 totalled 107, within the
720-request local daily budget.

Verification: 61 RSpec examples, adding history window size limits,
earliest_timestamp parsing and rejection, holiday-gap acceptance, collection
isolation and legacy weekend-close regression handling.

## Acceptance window

On 2026-10-11 (UTC) the owner replaced the seven-elapsed-day requirement. M00
now passes on:

1. History windows for all fourteen pair/interval combinations. These evidence
   weekend and holiday behaviour, gaps, duplicates, OHLC validity and depth
   over months to years, not days.
2. A revision check: repeating the history windows hours later must show zero
   fingerprint mismatches. Run it with `bin/rails 'twelve_data:history[1]'`,
   which re-measures any combination not measured in the last hour.
3. At least 48 hours of cumulative live collection during trading hours,
   starting after the 2026-10-11 21:00 UTC reopen. Each combination must show reproduced closes
   with no mismatches, current freshness during trading hours, request counts
   within budget and recorded timeout/429/retry outcomes.
4. The unchanged licensing and retention review.

A live weekend closure observation under the New York 17:00 rule continues
after the window. It does not block progression; a failure reopens M00.

Live collection runs only while the developer is working: `bin/dev` starts a
`collect` process (`bin/rails twelve_data:watch`) that runs one collection cycle
per minute and stops with the dev server. No cron job or background worker is
installed. The 48 hours are therefore cumulative active collection during
trading hours. Periods with `bin/dev` stopped are operator gaps, not provider
gaps: on restart, collection fetches whatever is due and reproducibility
compares overlapping candles, but candles that closed and aged out of the
8-candle window while stopped are not observed live. Run
`bin/rails twelve_data:watch` on its own to collect without the web server.

## Retention-rights review

Reviewed on 2026-10-11 (UTC) against the [Terms of Use](https://twelvedata.com/terms)
(last updated 2026-01-01) and the
[commercial and personal usage article](https://support.twelvedata.com/en/articles/5332349-commercial-and-personal-usage)
(updated 2026-08-04). This is an engineering summary of the published text,
not legal advice. The decision belongs to the owner.

### What the sources say

| Question | Source text | Effect on fxtrack |
| --- | --- | --- |
| Is a private owner-only app allowed on Basic? | Individual plans are "strictly for personal or internal use"; acceptable uses include "internal tools for personal or organizational use". | Fits, provided only the owner sees the data. |
| May data be stored? | §2.2(a): "Access, receive, process, and store Data solely for Internal Use." | Yes, for internal use. |
| For how long? | §2.3(g) prohibits storing or caching "beyond permitted timeframes specified in the Documentation". §16.1(a): retain "for duration permitted by subscription". | No timeframe was found in the documentation or support articles. Open question. |
| What happens on cancellation? | §12.5(b) and §16.2(a): delete all Data within 30 days; §16.2(b): certify deletion on request. | A deletion procedure is required. |
| Who may see it? | §2.2(b): display to Authorized Users. Individual plans prohibit "commercial display of data to third parties" and redistribution (§2.3(b)). | Owner UI, charts, email and Telegram to the owner are allowed. Public pages must not show provider prices. |
| Indicators, signals and backtests | §2.2(c) and §6.2: the customer owns Derived Data that "cannot be reverse-engineered to recreate the original Data". §2.3(f) bars derivative financial products without permission. Backtesting is not mentioned. | Signals and indicators are Derived Data. Raw candles, charts and backtest inputs remain provider Data under the retention limits. |
| Third-party sources | §3.1(d) and §8.2(e): the customer must follow data-source restrictions. ASX data is internal-only on every tier. | No forex-specific source restriction was found. |

### Implications for later milestones

- M01 landing page: the product preview must use illustrative or fixture
  data, never live or stored Twelve Data prices, because the page is public.
- M03 charts, M07 signals and M08 alerts: allowed for the owner alone. Alerts
  must not be forwarded to other people or channels.
- M03/M11 candle storage: allowed for internal use while the subscription is
  active, subject to the unresolved documentation timeframe.
- Cancellation: add a documented task that deletes all stored candles within
  30 days of cancelling. Keyed fingerprints and quality metrics are Derived
  Data and may stay.

### Owner decision

On 2026-10-11 (UTC) the owner chose to record an interpretation instead of
waiting for a written answer from Twelve Data. The accepted interpretation:

- fxtrack may store Twelve Data candles in its own database for internal,
  owner-only use for as long as the subscription is active. This relies on
  §2.2(a) and §16.1(a), because no shorter timeframe was found in the
  Documentation referenced by §2.3(g).
- All stored candles are deleted within 30 days of the subscription ending,
  as §12.5(b) and §16.2(a) require. The task that stores candles must ship
  with a documented deletion task.
- Stored data is never displayed to anyone other than the owner, never
  redistributed and never used on public pages.

Accepted risk: if the Documentation does specify a shorter storage or caching
timeframe, fxtrack would be out of compliance until it adopts that limit. The
owner accepts this risk. Re-check the Terms and support articles whenever
storage behaviour changes, and adopt any published timeframe immediately.

This resolves the M00 rights review. M00 itself stores no candle prices;
persistence arrives with the milestones that need it, under this decision.

Check progress against this gate with `bin/rails twelve_data:acceptance`. It
prints each criterion as passed or pending, then one line per pair/interval
with live requests, outcomes, error codes, reproduced and mismatched closes,
invalid candles, latest freshness and history-window status. Live hours count
distinct trading-hour buckets containing a successful live request with a
valid or closed quality result and at least one trading candle since
2026-10-11 21:00 UTC; failed attempts and weekend hours never count.
Rejected history responses remain included in mismatch totals. The live
freshness check requires every pair/interval to cover its latest expected
trading close, with no newer failed request.
