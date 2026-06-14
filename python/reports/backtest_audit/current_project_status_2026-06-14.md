# Current Project Status - 2026-06-14

## Documentation update

- Reviewed the repository state and synced the progress summary back into `README.md`.
- Confirmed this file is the dedicated continuation status note for the current work session.
- Current documentation stance: MT5 remains the validation source of truth; Python is the research/analysis assistant for feature discovery, parameter hypotheses, candidate generation, and diagnostics.
- Follow-up fixes applied:
  - `python/core/backtest_engine.py` now uses the signal-generated `entry` price instead of always entering at the M15 close.
  - Removed the duplicate `use_ema200_trend_filter: true` override from `python/config.yaml`; the EA does not have this EMA200 filter.
  - `python/experiments/exp001_baseline.py` now warns when M5 coverage does not span the M15 research range.
  - `python/tools/sync_mt5_history.py` now warns when MT5 returns history starting later than the requested range.
  - `python/tools/reconcile_mt5_python.py` parses MT5 Strategy Tester HTML Orders/Deals and builds Python-vs-MT5 reconciliation CSVs.
  - `python/experiments/exp002_intrabar_candidates.py` scans M5 bars for intrabar candidates using M15 strategy context.
  - `python/experiments/exp003_m5_intrabar_backtest.py` runs an M5 execution-cadence diagnostic backtest.
  - Added M30 higher-timeframe EMA confirmation to Python indicators/signals to match the EA regime filter.
  - Fixed same-bar managed-stop lookahead: newly modified BE/trailing stops are no longer tested against the same completed bar.
  - Shifted workflow back to the intended architecture: Python analyzes MT5 truth data and generates hypotheses; MT5 validates all candidate EA changes.
  - Added `python/analysis/mt5_trade_feature_analysis.py` to parse MT5 Strategy Tester reports, enrich trades with market features, and generate analysis outputs.
  - Added `python/reports/analysis/baseline_m15_aligned_feature_analysis.md`.
  - Added `python/reports/analysis/baseline_m15_aligned_research_hypotheses.md`.

## Where the project stands

- The EA source and compiled binary are present at the repository root:
  - `XAUUSD_Regime_EA.mq5`
  - `XAUUSD_Regime_EA.ex5`
  - `XAUUSD_Regime_EA_trend_v3.set`
- The historical MT5/OHLC audit phase is complete enough to identify prior strong versions.
- The newer Python research pipeline exists, but it is not yet a faithful EA simulator.
- Existing MT5 split tests show the current baseline is regime-sensitive:
  - train `2024.02.23 -> 2025.06.01`: net `34.69`, PF `1.33`, trades `44`
  - test `2025.06.01 -> 2026.01.01`: net `-38.91`, PF `0.44`, trades `18`
  - valid `2026.01.01 -> 2026.06.12`: net `192.90`, PF `4.23`, trades `17`
- Existing candidate `candidate_m15_v1` is not acceptable:
  - train net `-10.72`, PF `0.93`
  - test net `-32.19`, PF `0.37`
  - valid net `120.89`, PF `2.57`

## Work completed in this continuation

- Connected directly to the local running MT5 terminal:
  - terminal: `C:\Program Files\MetaTrader 5\terminal64.exe`
  - account server: `TradeMaxGlobal-Live`
  - symbol: `XAUUSD`
- Added `python/tools/sync_mt5_history.py` to pull OHLC data from MT5 without manual export.
- Added `MetaTrader5>=5.0.5735` to `python/requirements.txt`.
- Synced raw data from MT5:
  - `python/data/raw/XAUUSD_M15.csv`: `2023-01-03 08:00:00 -> 2026-06-13 07:45:00`, `67,918` rows
  - `python/data/raw/XAUUSD_M5.csv`: `2025-01-14 10:15:00 -> 2026-06-13 07:50:00`, `100,000` rows
  - Re-syncing from `2023-01-01` still returns only `100,000` M5 rows, so the M5 gap is caused by the local MT5 terminal history limit / available broker history, not by the project loader.
- Aligned `python/config.yaml` with the current root `.set` for 11 previously drifted parameters:
  - trend buy RSI
  - long-trend efficiency offset
  - signal-bar trend entry
  - intrabar trend ADX
  - wider trend stop
  - trend ATR stop multiplier
  - trend RR
  - long-trend RR
  - short-trend RR
  - breakeven stop
  - ATR trailing stop
- Re-ran `python/experiments/exp001_baseline.py` after the entry-price and EMA200-filter fixes:
  - after M30 confirmation and stop-management fix, full Python baseline: net `40.68`, PF `1.26`, trades `26`
  - warning emitted: `34,469` M15 bars predate available M5 history and cannot be truly M5-intrabar aligned.
- M5-cadence diagnostics on valid `2026-01-01 -> 2026-06-12`:
  - `exp002_intrabar_candidates.py`: 33 raw M5 candidates.
  - `exp003_m5_intrabar_backtest.py`: net `42.42`, PF `1.22`, trades `22`.
  - MT5 baseline valid remains net `192.90`, PF `4.23`, trades `17`.
  - MT5-vs-M5-candidate matching found 8/17 MT5 entries within 5 minutes and 9/17 within 15 minutes before full position/risk filtering.
  - MT5-vs-exp003 matching found 7/17 entries within 5 minutes and 8/17 within 15 minutes.
- MT5 trade feature analysis:
  - Parsed 79 MT5 baseline-aligned trades across train/test/valid.
  - Output: `python/reports/analysis/baseline_m15_aligned_trade_features.csv`.
  - Report: `python/reports/analysis/baseline_m15_aligned_feature_analysis.md`.
  - Research hypotheses: `python/reports/analysis/baseline_m15_aligned_research_hypotheses.md`.
  - Key hypotheses for MT5 validation:
    - Raise/scan trend efficiency floor: poor bin `0.25-0.34` had Net `-46.58`, while `0.45-0.60` had Net `120.53`.
    - Test stricter trend choppiness ceiling: choppiness `55-65` had Net `-8.93`.
    - Investigate short RSI middle-band weakness: RSI `32-38` had Net `-23.34`, while RSI `<=28` had Net `172.76`.
    - Test absolute ATR / `InpMinAtrFactor` sweeps; higher ATR bins carried most profit.
    - Session filters should be broad and MT5-validated, not cherry-picked by single hour.

## Important finding

The Python engine is still not equivalent to the EA.

Using the same split dates after config alignment:

| split | Python trades | Python net | Python PF | MT5 trades | MT5 net | MT5 PF |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| train | 10 | -40.20 | 0.06 | 44 | 34.69 | 1.33 |
| test | 7 | 10.29 | 1.28 | 18 | -38.91 | 0.44 |
| valid | 9 | 70.58 | 1.94 | 17 | 192.90 | 4.23 |

The gap is smaller but still too large for Python-only optimization to be trusted. The trade-count gap narrowed in valid and several MT5 entries now have close Python M5 candidates. Remaining causes include M5 history starting at `2025-01-14`, approximate M30 bar alignment, missing range-grid execution, incomplete recovery/daily-trade accounting, bid/ask/spread execution differences, and remaining MT5 tester sequencing details.

## Recommended next step

Use MT5 as the source of truth for candidate validation. Use Python primarily for trade-feature analysis, market-regime diagnostics, parameter hypothesis generation, and experiment planning.

Immediate next engineering step:

1. Run MT5 validation sweeps for the hypotheses in `baseline_m15_aligned_research_hypotheses.md`.
2. Start with efficiency floor, trend choppiness ceiling, ATR floor / `InpMinAtrFactor`, then short RSI middle-band diagnostics.
3. Validate each candidate on train/test/valid, rolling 6-month windows, and verylong.
4. Increase MT5 `Max bars in chart` / download deeper M5 broker history, then re-run `python/tools/sync_mt5_history.py --symbol XAUUSD --timeframes M15 M5 --from 2023-01-01`.
5. Keep `python/tools/reconcile_mt5_python.py` for diagnostics, not as the primary optimization objective.
