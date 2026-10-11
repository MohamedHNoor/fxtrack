# Strategies and signals

FXTrack proposes trades; it never places them, creates journal trades or moves
capital. The owner decides whether to act on a signal.

## Trend Pullback Confirmation V1

The default strategy (owner-approved parameters, 2026-10-11) is created for the
owner automatically. On each enabled pair's latest completed H1 candle it
checks, in order, and stops at the first failed rule with a WAIT reason:

1. Enough history: more than the slow EMA period of H4 candles, and enough H1
   candles for the slow EMA, swing lookback and ATR.
2. Trend: EMA20 above EMA50 on both completed H4 and H1 is bullish (buys);
   below on both is bearish (sells). Disagreement waits.
3. Level: the most recent confirmed swing low below price (buy) or swing high
   above price (sell) within the last 50 H1 candles. A swing needs 3 candles
   on each side, so the newest candles can never form one (no lookahead).
4. Pullback: one of the last 3 H1 candles touched the zone (swing level +/-
   0.25 x ATR14), and the close has not broken through it.
5. Confirmation: the latest H1 candle is a bullish (buy) or bearish (sell)
   engulfing candle: its body covers the previous opposite-coloured body.
6. Stop: beyond the swing level by 0.5 x ATR14, widened to at least 10 pips.
7. Room: the next confirmed opposite swing must be at least the reward
   multiple (from settings, default 2R) times the stop distance away.

Entry is the confirmation candle's close and the target is entry +/- reward
multiple x stop distance. Every number is editable on `/strategies`; edits
create a new immutable version and earlier signals keep theirs. Only bounded,
supported parameters exist; strategies never run user code.

## Engine and lifecycle

`MarketDataCollectionJob` runs `Strategies::SignalEngine` after each
collection cycle, so analysis happens only while an owner session is valid.
For each running strategy and enabled pair it evaluates the latest H1 candle
once (a unique run per strategy version, pair and candle) and only when that
candle is fresh, so late data and restarts never create retroactive signals.
Every evaluation is stored as a strategy run with its verdict, reasons and
evidence.

A BUY or SELL creates a signal sized with the risk settings: the structural
stop distance plus the strategy's assumed 1.5-pip spread (Twelve Data supplies
no live spread). A database unique index prevents duplicate signals.

| Status | When |
| --- | --- |
| active | Created; actionable until expiry |
| expired | 30 minutes (configurable) after the confirmation candle closed |
| invalidated | A newer candle traded through the stop, or closed beyond the entry tolerance (0.25 x ATR) |
| completed | Reserved for the journal (M10); nothing completes signals yet |

The page countdown is only a guide; the stored status decides validity.

## Screens

- `/signals`: active trade ideas (entry, stop, target, lots, NZD risk,
  countdown), a correlated US-dollar exposure warning when two or more live
  signals lean the same way on USD (for example buying NZD/USD and AUD/USD),
  the latest verdict and reason for every enabled pair, and recent history.
- `/signals/:id`: plan, sizing working and the evidence behind the verdict.
- `/strategies`: enable/disable, edit rules (new version), clone (disabled
  copy) and archive (stops running, keeps history).
- The dashboard's Active signals card counts live signals.

## Limits

- Signals are only as current as stored H1 data; an H1 strategy cannot react
  inside the hour.
- Spread is an assumption, and composite prices can differ from the broker's.
- Backtests (M11) and paper testing (M09) are needed before trusting any
  strategy; signals are not a promise of profit.
