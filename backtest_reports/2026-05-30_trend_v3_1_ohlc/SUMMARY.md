# trend v3.1 OHLC Backtest Summary

Date: 2026-05-30

## Purpose

This run validates the K-line synchronized intraday trend strategy using fast 1Min OHLC backtests, with reports archived alongside the exact EA source and set file used for the run.

## Configuration

- Symbol: XAUUSD
- Signal timeframe: M15
- Higher timeframe: M30
- Entry trigger: M15 trend pullback plus closed M5 breakout
- Pricing model: 1Min OHLC for train/test/validation and long-sample screening
- Execution latency: 250 ms
- Initial deposit: 100 USD
- Lot size: fixed 0.01
- Max actual risk: 8%
- Trend stop: ATR/structure combination, `InpUseWiderTrendStop=false`, `InpTrendAtrStopMultiplier=1.35`
- Breakeven: 1.0R
- ATR trailing: starts at 1.6R, managed only on new M5 bars

## Results

| Segment | Window | Trades | Net Profit | Profit Factor | Equity DD |
| --- | --- | ---: | ---: | ---: | --- |
| Train | 2025.05.22 - 2026.01.22 | 10 | +7.20 USD | 1.21 | 20.36 USD (17.79%) |
| Test | 2026.01.22 - 2026.04.22 | 1 | -7.75 USD | 0.00 | 8.52 USD (8.45%) |
| Validation | 2026.04.22 - 2026.05.22 | 5 | +7.53 USD | 1.41 | 21.54 USD (19.50%) |
| Full year | 2025.05.22 - 2026.05.22 | 10 | +7.20 USD | 1.21 | 20.36 USD (17.79%) |

## Trade Count Diagnosis

The strategy checks many bars but opens very few trades. In the full-year run the diagnostic summary was:

- bars: 23852
- trendUp: 2126
- trendDown: 1323
- range: 4900
- unclear: 15503
- buySignals: 546
- sellSignals: 368
- blocked: 904
- attempts: 10
- success: 10

The main bottleneck is not lack of trend regimes or raw signals. The bottleneck is the execution gate after signals are generated:

- `InpMaxActualRiskPercent=8` blocks many signals because XAUUSD 0.01 lot on a 100 USD account makes normal trend stops large in account-percent terms.
- `InpMaxOpenPositions=1` allows only one managed position at a time.
- `InpMinBarsBetweenTrades=2` adds cooldown.
- K-line synchronized M5 breakout filters require confirmed closed-bar breakouts, which intentionally removes tick-noise entries.
- Entry quality filters require a meaningful candle body, strong close position, and no abnormal entry bar.

## Current Assessment

This candidate is more realistic than the earlier tick-sensitive version, and the OHLC/real-tick behavior is expected to be closer because entries and stop management are synchronized to K-line boundaries. However, the strategy is not stable yet:

- Test segment has only 1 trade and is negative.
- Total samples are too few for robust conclusions.
- The strategy is still constrained by small-account minimum lot risk.

Next optimization should focus on increasing high-quality trade frequency without relying on tick noise, especially by tuning trend thresholds, entry-bar quality filters, and risk gating across train/test/validation splits.
