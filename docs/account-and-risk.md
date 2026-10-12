# Account and risk

## Account ledger (`/account`, linked from settings)

The owner sets up one NZD trading account with a starting capital and start
time. Both are fixed once saved; later changes are ledger entries.

Balance = starting capital + deposits - withdrawals + realized closed-trade
P&L + adjustments + reversals. Closed journal trades post their realized NZD
P&L as `trade` entries (see `docs/journal.md`). Unrealized P&L is never
included.

| Entry | Stored amount | Notes |
| --- | --- | --- |
| Deposit | positive | |
| Withdrawal | negative | Rejected if it would make the balance negative |
| Adjustment | positive or negative | Direction chosen explicitly |
| Reversal | exact negative of the original | One per entry; reversals cannot be reversed |
| Trade P&L | realized NZD P&L of a closed journal trade | Posted and corrected only through the journal; no Reverse button |

Entries are immutable: the model is read-only once saved, there are no update
or delete routes, and corrections are recorded as reversals. Database check
constraints enforce signs and the reversal link. A database trigger was
considered but `db/schema.rb` cannot represent triggers, so test and freshly
loaded databases would silently lack it.

Times entered in forms are read as Pacific/Auckland wall-clock time
(`config.x.owner_time_zone`).

## Risk & account settings (`/settings`)

The settings page follows the design prototype: a Risk management card (account
currency, current capital, risk fields and the resulting planned risk per
trade), a Capital management card (balance, link to the ledger, timezone and
alert preferences), a read-only Currency pair preferences card (toggles arrive
with M04) and the position calculator. `/risk` redirects here. Risk settings
save to `PATCH /settings/risk`.

### Risk settings and position size

Defaults: 1% of the current balance, a 40-pip stop distance, 2.0R reward and
a 0.01 minimum lot and step. Fixed NZD risk and an optional maximum-loss cap
are available. Settings are saved only when the owner submits them.
Per-strategy overrides arrive with strategies (M06).

The calculator needs only a currency pair; it recalculates when the pair
changes and never saves anything or moves capital. Everything else comes from
the saved settings and stored prices:

1. Risk = balance x risk % (or the fixed NZD amount), capped by the maximum
   loss.
2. US-dollar risk budget = NZD risk x NZD/USD.
3. Pip value per standard lot (100,000 units) in USD = pip size x 100,000 x
   USD per quote unit: US$10 for USD-quoted pairs, and 1,000 / price for
   USD/JPY (pip 0.01) or 10 / price for USD/CHF and USD/CAD.
4. Lots = USD risk / (stop pips x USD pip value), rounded down to the lot
   step. Below the broker minimum the calculator explains why instead.
5. Loss at that size is converted back to NZD and shown with the reward at the
   target.

Worked example: NZ$2,000 x 1% = NZ$20; at NZ$1 = US$0.60 that is US$12; with a
40-pip EUR/USD stop at US$10 per pip per lot, 12 / (40 x 10) = 0.03 lots, and a
40-pip adverse move costs about NZ$20, excluding trading costs, slippage and
currency conversion fees.

Entry is the pair's latest stored H1 close. The page shows a buy plan (stop
below entry, target above) and a sell plan (stop above, target below), with
the target at the reward multiple times the stop distance. NZD/USD comes from
the latest stored close; NZD/USD trades use their own price. Until prices are
stored, the page asks for the pair price or NZD/USD rate it is missing. A
fixed pip value in NZD is never assumed, and the result names every price
used.

Fixed NZD risk changes the size without moving the balance.
