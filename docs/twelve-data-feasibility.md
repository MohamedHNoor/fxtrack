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
all probe processes. Every attempt reserves at least one credit; unknown costs
and crashed reservations still consume local budget. Response credit headers
are recorded when numeric, and a low minute balance pauses further requests.
This cannot coordinate independent applications sharing the same key; their
consumption must be accounted for before unattended observation. No paid
upgrade is performed.

There are at most three attempts per explicit probe, with 5-second connect/write
and 10-second read timeouts. HTTP internal retries are disabled. Timeout,
transport failures, 429 and HTTP 5xx can retry with bounded backoff. Numeric
Retry-After above 60 seconds causes a stop, not a long sleeping process.
Unknown or nonnumeric credit headers remain nil. Provider response bodies,
prices and exception messages are not persisted in metrics. No candle table
exists while storage rights are unresolved.

## Outstanding implementation and observation gates

This is a diagnostic foundation, not a completed M00 implementation. Explicit
probe tasks do not yet implement close-aligned recurring collection, catalogue
validation, cross-request reproducibility or verified market-closure handling.
Freshness and gap diagnostics conservatively reject stale/gapped data and do
not assume weekends are feed failures or confirmed closures. The seven-day run
must wait for those collection semantics to be verified. Historical retention
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
