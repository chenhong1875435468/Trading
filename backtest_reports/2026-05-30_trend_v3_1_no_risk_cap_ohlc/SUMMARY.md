# trend v3.1 No Risk Cap OHLC Backtest Summary

Date: 2026-05-30

## Change

`InpMaxActualRiskPercent` was set to `0.0`, which disables the actual-risk-percent gate. This isolates the strategy from the 100 USD small-account minimum-lot constraint.

## Results

| Segment | Window | Trades | Net Profit | Profit Factor | Equity DD |
| --- | --- | ---: | ---: | ---: | --- |
| Train | 2025.05.22 - 2026.01.22 | 3 | -12.50 USD | 0.46 | 24.85 USD (22.12%) |
| Test | 2026.01.22 - 2026.04.22 | 2 | +11.56 USD | 2.24 | 15.86 USD (15.04%) |
| Validation | 2026.04.22 - 2026.05.22 | 4 | -38.82 USD | 0.01 | 47.79 USD (43.86%) |
| Full year | 2025.05.22 - 2026.05.22 | 3 | -12.50 USD | 0.46 | 24.85 USD (22.12%) |

## Diagnosis

Removing the risk cap did not increase trade count. In the full-year run:

- buySignals: 546
- sellSignals: 368
- blocked: 911
- attempts: 3
- success: 3

Likely cause: larger accepted stop distances on a 0.01 lot XAUUSD position cause normal losses to exceed daily loss and consecutive-loss controls quickly. So the next bottleneck is no longer actual-risk-percent, but daily/consecutive loss gates and entry quality.

## Current Assessment

This run confirms that small-account risk cap was one blocker, but simply removing it is not enough. For strategy research, the next run should also use research-mode daily loss settings, or separately track signal quality without daily account shutdown.
