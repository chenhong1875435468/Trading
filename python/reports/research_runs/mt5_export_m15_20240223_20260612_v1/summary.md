# XAUUSD Research Pipeline

> Python results are research filters. Confirm every candidate in MT5 Strategy Tester before EA changes or live use.

## Data Quality

- rows: 54416
- start: 2024-02-23T01:00:00
- end: 2026-06-12T23:45:00
- timeframe: M15
- duplicate_timestamps: 0
- missing_bars: 26316
- null_counts: {}
- invalid_ohlc_rows: 0

## Selected Parameters

- fast_ema_period: 21
- slow_ema_period: 55
- adx_period: 14
- trend_adx_threshold: 22.0
- range_adx_threshold: 18.0
- rsi_period: 14
- trend_buy_max_rsi: 66.0
- trend_sell_min_rsi: 28.0
- atr_period: 14
- min_atr_factor: 0.5
- bands_period: 20
- range_lookback_bars: 36
- range_min_width_atr: 2.0
- range_max_width_atr: 5.0
- range_ema_gap_atr: 1.6
- min_trend_efficiency_ratio: 0.34
- max_trend_choppiness: 55.0
- min_trend_ema_gap_atr: 0.25
- min_trend_di_gap: 6.0
- pullback_atr: 0.25
- breakout_buffer_atr: 0.05
- range_edge_buffer_atr: 0.25
- range_reward_risk: 1.0
- trend_atr_stop_multiplier: 1.5
- trend_reward_risk: 2.9
- long_trend_reward_risk: 1.7
- short_trend_reward_risk: 0.0
- max_signal_bar_atr: 1.2
- allow_range: True
- allow_trend: True

## Train/Test/Valid Evaluation

split  trades  net_profit  profit_factor  win_rate  max_drawdown  max_drawdown_pct  expectancy     avg_r  fast_ema_period  slow_ema_period  adx_period  trend_adx_threshold  range_adx_threshold  rsi_period  trend_buy_max_rsi  trend_sell_min_rsi  atr_period  min_atr_factor  bands_period  range_lookback_bars  range_min_width_atr  range_max_width_atr  range_ema_gap_atr  min_trend_efficiency_ratio  max_trend_choppiness  min_trend_ema_gap_atr  min_trend_di_gap  pullback_atr  breakout_buffer_atr  range_edge_buffer_atr  range_reward_risk  trend_atr_stop_multiplier  trend_reward_risk  long_trend_reward_risk  short_trend_reward_risk  max_signal_bar_atr  allow_range  allow_trend               start                 end  trade_rows
train     218   -0.389608       0.879674 46.330275      0.763119          0.762768   -0.001787 -0.036697               21               55          14                 22.0                 18.0          14               66.0                28.0          14             0.5            20                   36                  2.0                  5.0                1.6                        0.34                  55.0                   0.25               6.0          0.25                 0.05                   0.25                1.0                        1.5                2.9                     1.7                      0.0                 1.2         True         True 2024-02-23 01:00:00 2025-05-30 23:45:00         218
 test     110   -1.396463       0.493129 40.000000      1.486182          1.484850   -0.012695 -0.193636               21               55          14                 22.0                 18.0          14               66.0                28.0          14             0.5            20                   36                  2.0                  5.0                1.6                        0.34                  55.0                   0.25               6.0          0.25                 0.05                   0.25                1.0                        1.5                2.9                     1.7                      0.0                 1.2         True         True 2025-06-02 01:15:00 2025-12-31 23:45:00         110
valid      70    0.344594       1.078559 38.571429      1.802105          1.804839    0.004923 -0.110000               21               55          14                 22.0                 18.0          14               66.0                28.0          14             0.5            20                   36                  2.0                  5.0                1.6                        0.34                  55.0                   0.25               6.0          0.25                 0.05                   0.25                1.0                        1.5                2.9                     1.7                      0.0                 1.2         True         True 2026-01-02 01:15:00 2026-06-12 23:45:00          70

## Artifacts

- Grid search: `/Users/ch/Documents/Codex/2026-06-14/chenhong1875435468-trading-https-github-com-chenhong1875435468/python/reports/research_runs/mt5_export_m15_20240223_20260612_v1/grid_search.csv`
- Split evaluation: `/Users/ch/Documents/Codex/2026-06-14/chenhong1875435468-trading-https-github-com-chenhong1875435468/python/reports/research_runs/mt5_export_m15_20240223_20260612_v1/split_evaluation.csv`
- Trades: `/Users/ch/Documents/Codex/2026-06-14/chenhong1875435468-trading-https-github-com-chenhong1875435468/python/reports/research_runs/mt5_export_m15_20240223_20260612_v1/trades.csv`
- Selected params: `/Users/ch/Documents/Codex/2026-06-14/chenhong1875435468-trading-https-github-com-chenhong1875435468/python/reports/research_runs/mt5_export_m15_20240223_20260612_v1/selected_params.json`
- Grid config: `/Users/ch/Documents/Codex/2026-06-14/chenhong1875435468-trading-https-github-com-chenhong1875435468/python/config/research_grid_default.json`
- MT5 candidate set: `/Users/ch/Documents/Codex/2026-06-14/chenhong1875435468-trading-https-github-com-chenhong1875435468/python/reports/research_runs/mt5_export_m15_20240223_20260612_v1/candidate.set`
