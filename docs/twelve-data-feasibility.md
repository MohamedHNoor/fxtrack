# Twelve Data feasibility evidence

Status: preparation only. No live requests, seven-day observation or provider
price persistence have started. M00 remains open.

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
No probe task or public provider endpoint exists yet.
