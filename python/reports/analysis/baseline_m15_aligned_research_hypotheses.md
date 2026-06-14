# Baseline M15 Aligned - Research Hypotheses

Source of truth: MT5 Strategy Tester trades from `baseline_m15_aligned` train/test/valid.

Python role: enrich MT5 trades with market features and generate hypotheses for EA filters/parameters. These are not final conclusions until validated in MT5.

## Dataset

- MT5 trades analyzed: 79
- Splits:
  - train: 44 trades, Net 32.02, Win 56.82%
  - test: 18 trades, Net -38.19, Win 55.56%
  - valid: 17 trades, Net 191.29, Win 70.59%
- Dominant setup: trend trades, 77 of 79 trades.
- Direction skew: SELL trades contributed most net profit; BUY trades were frequent winners but low total net.

## Candidate Hypotheses For MT5 Validation

### 1. Trend efficiency filter may need a higher floor

Feature bin result:

- Efficiency 0.25-0.34: 8 trades, Net -46.58, Win 12.50%
- Efficiency 0.45-0.60: 28 trades, Net 120.53, Win 75.00%
- Efficiency 0.60-1.00: 12 trades, Net 62.07, Win 83.33%

Hypothesis:

- Test raising trend quality requirements so trend entries avoid low-efficiency continuation setups.
- Candidate sweeps:
  - `InpMinTrendEfficiencyRatio`: 0.34 -> 0.40 / 0.45
  - `InpLongTrendEfficiencyOffset`: keep current 0.12 initially, then retest after base filter.

### 2. Choppiness 55-65 looks weak for trend entries

Feature bin result:

- Choppiness 55-65: 3 trades, Net -8.93, Win 0.00%
- Choppiness 45-55: 40 trades, Net 152.12
- Choppiness 35-45: 33 trades, Net 23.60

Hypothesis:

- Test a stricter trend choppiness ceiling.
- Candidate sweeps:
  - `InpMaxTrendChoppiness`: 55 -> 52 / 50 / 48

### 3. Medium RSI short entries are weaker than momentum continuation shorts

Feature bin result:

- RSI <= 28: 26 trades, Net 172.76, Win 80.77%
- RSI 28-32: 10 trades, Net 22.86
- RSI 32-38: 13 trades, Net -23.34

Hypothesis:

- The EA is doing well when short entries are true downside momentum continuation, not when RSI has already rebounded into the 32-38 middle band.
- Candidate sweeps:
  - `InpTrendSellMinRsi`: current 28.0 may be permissive after rebound; test 30 / 32 / 34 carefully.
  - Add a diagnostic filter: avoid short entries when RSI is between 32 and 38 unless efficiency is high.

### 4. Absolute ATR regime matters

Feature bin result:

- ATR 12-18: 9 trades, Net 86.76
- ATR 8-12: 14 trades, Net 64.37
- ATR <= 8: 56 trades, Net 33.99

Hypothesis:

- The EA makes most of its money when absolute volatility is high enough; low-ATR trades are numerous but low value.
- Candidate sweeps:
  - Add/test absolute ATR floor for trend entries.
  - Or increase `InpMinAtrFactor` from 0.50 to 0.60 / 0.70 while checking trade count.

### 5. Session filter should be tested, not assumed

Feature result:

- Strong hours in this sample: 20, 22, 6, 19.
- Weak hours in this sample: 7, 23, 21, 12.

Hypothesis:

- A session filter may improve stability, but sample size by hour is small.
- Candidate validation:
  - Test broad sessions first, not single-hour cherry picking.
  - Example windows: 04-23 baseline vs 06-23 vs 18-23 vs excluding 07/21/23.

## Recommended MT5 Experiment Order

1. Efficiency floor sweep.
2. Trend choppiness ceiling sweep.
3. ATR floor / `InpMinAtrFactor` sweep.
4. RSI short-entry diagnostic sweep.
5. Broad session filter sweep.

Each experiment should be validated on:

- train/test/valid splits
- rolling 6-month windows
- verylong full period

Do not promote a parameter if it improves valid only while damaging train/test robustness.
