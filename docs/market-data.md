# Market data

## Collection

`MarketDataCollectionJob` runs one bounded collection cycle (see
`docs/twelve-data-feasibility.md`) only while at least one owner session is
valid (`Session.active`). Expiry or logout of the last session pauses
monitoring; closing the browser does not.

- Development: `bin/dev` starts `bin/rails twelve_data:watch`, which runs the
  job every minute and prints only when requests are made or the status
  changes (`collected`, `no_active_session`, `already_running`).
- Production: `config/recurring.yml` schedules the job every minute under
  Solid Queue.

Collection still covers all seven pairs at H1 and H4 because the M00 evidence
window depends on it. Restricting ingestion to enabled pairs belongs to M04.

## Candle storage

Every successful `time_series` and `time_series_history` evaluation stores its
closed trading candles in `candles`, unique by symbol, interval and open time.
Stored candles have passed validation and the fingerprint reproducibility
check; weekend candles, invalid candles and unreproducible responses are never
stored. Prices are `decimal(16, 8)`. The database rejects non-positive or
inconsistent OHLC values.

Storage follows the owner retention decision of 2026-10-11 (internal owner use
while subscribed). Delete every stored candle within 30 days of cancelling the
Twelve Data subscription:

```sh
CONFIRM=yes bin/rails twelve_data:delete_candles
```

## Screens

- `/dashboard`: watchlist of enabled pairs with the latest H1 close, change
  and H1/H4 data status, monitoring status, session details, and empty states
  for account balance and signals until M05 and M07.
- `/markets` and `/markets/:pair` (for example `/markets/EURUSD`): H1 or H4
  candlestick chart of the latest 300 stored candles using TradingView
  Lightweight Charts, vendored through import maps. The chart keeps the
  TradingView attribution logo the library license requires.

Data status per pair and interval is `No data yet`, `Provider failing`,
`Market closed` (New York 17:00 weekend rule), `Stale` (the last trading candle
that should have closed is missing) or `Fresh`. Times display in
Pacific/Auckland.

## Currency pairs

`currency_pairs` holds the seven supported pairs, all enabled by default.
`db/seeds.rb` calls `CurrencyPair.ensure_seeded!`, which adds missing pairs
without changing existing rows; `bin/rails db:prepare` runs it for a new
database. Toggling pairs is M04.
