# Twelve Data feasibility evidence

Status: diagnostic implementation in progress. A bounded live request failed
before any HTTP response; seven-day observation and provider price persistence
have not started. M00 remains open.

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
duration for this account. Historical price storage remains blocked until its
applicable permission and duration are documented. Sanitized diagnostic metrics
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
- At least seven elapsed days of traceable observations including closures.

## Current local checks

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
and do not contribute candle coverage. Test the other six symbols explicitly.
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
