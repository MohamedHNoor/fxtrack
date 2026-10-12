# Trading journal

The journal (`/journal`) records what the owner actually did at the broker.
FXTrack never places trades, and signals never create journal records or move
capital. Only an explicit owner submission does.

## Records

Each record is one decision:

- **Taken**: pair, direction, opened time, actual entry price and units
  (base currency; 100,000 units is one standard lot). It stays **open** until
  the close fields are filled in.
- **Closed**: a taken trade with exit price, closed time and closing rate, plus
  optional NZD fees and financing.
- **Skipped**: pair, direction, the time it was skipped and notes. No fills,
  costs or P&L.

A record can link to one generated signal (use "Record in journal" on the
signal page). The signal's planned levels are shown for reference only and its
status is not changed. One entry and one exit per record: record a partial
close as separate trades. The decision (taken or skipped) and the signal link
cannot be changed later, and records cannot be deleted.

Times are entered and shown as New Zealand wall-clock time. Times in the
future, and closes before opens, are rejected.

## Realized NZD P&L

The closing rate is the quote currency per 1 NZD, for example NZD/USD 0.5800
for a USD-quoted pair or NZD/JPY 88.50 for a JPY-quoted pair. Fees are a
positive NZD cost; financing is signed NZD (positive credit, negative charge).

```
quote P&L      = (exit - entry) x units x (+1 buy, -1 sell)
calculated P&L = quote P&L / closing rate - fees + financing
```

The result is rounded once to cents, half up. Examples:

| Trade | Calculation | NZD |
| --- | --- | --- |
| EUR/USD buy 10,000 units, 1.10000 to 1.10500, rate 0.5800, fees 1.50, financing -0.30 | 50 / 0.58 - 1.50 - 0.30 | 84.41 |
| USD/JPY sell 20,000 units, 150.00 to 149.50, rate 88.50 | 10,000 / 88.50 | 112.99 |

A **manual override** replaces the calculated amount when the broker's
realized NZD amount differs. It needs a reason. Both amounts stay visible, and
the page and CSV show which one is used (`calculated` or `override`).

## Ledger and balance

Closing a trade posts its realized P&L to the account ledger as a `Trade P&L`
entry dated at the close. A breakeven trade posts nothing. Open trades are not
in the balance:

```
balance = starting capital + deposits - withdrawals + realized closed-trade P&L + adjustments
```

Trade postings cannot be reversed from the account page.

## Corrections and audit history

Every create and change writes an immutable audit event: who, when, and each
changed field's before and after value. Changing a trade that is already closed
is a **correction**: it needs a reason. If the realized amount or close time
changes, the old ledger posting is reversed (dated at the original close) and a
new one is posted, in the same transaction as the edit. Saving without changes
records nothing.

## CSV export

"Export CSV" downloads the records matching the current filters (pair, state,
strategy, and From/To New Zealand dates applied to the opened or skipped time)
as `fxtrack-journal-YYYYMMDD.csv`. Columns:

`id, state, pair, direction, signal_id, strategy, opened_at, closed_at,
skipped_at, entry_price, exit_price, units, lots, fees_nzd, financing_nzd,
closing_rate_quote_per_nzd, calculated_pnl_nzd, override_pnl_nzd,
realized_pnl_nzd, pnl_source, override_reason, notes, corrections, updated_at`

Times are ISO 8601 in New Zealand time with the offset; numbers are plain
decimals. Text cells that start with `=`, `+`, `-`, `@`, tab or carriage return
are prefixed with `'` so spreadsheets do not run them as formulas. The export
requires the owner to be logged in.

## Manual acceptance checklist

1. Log in, open Journal and record an open EUR/USD buy. The account balance is
   unchanged.
2. Close it with the first worked example. The record shows +NZD 84.41
   (Calculated), and the account shows a linked Trade P&L entry with no Reverse
   button.
3. Edit the closed trade without a correction reason: it is refused. Add an
   override of 80 with a reason and a correction reason: the balance moves by
   -4.41, the ledger shows a correction and a new posting, and the audit
   history lists the correction.
4. Record a skipped trade from a signal page; the signal stays as it was, and
   the signal page now links to the record.
5. Filter by state and dates, export CSV, and check the columns and the
   override source.
6. Repeat on a phone-width screen: navigation drawer, form and tables remain
   usable.
