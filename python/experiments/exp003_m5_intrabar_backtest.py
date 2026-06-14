"""Experiment 003: M5 execution backtest for intrabar trend candidates.

This uses M15 indicators/regimes for strategy context, scans M5 bars for entries,
then executes on M5 OHLC. It is still a simplified simulator, but it is closer to
the EA cadence than exp001, which only opened on M15 rows.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).parent.parent))

from core.backtest_engine import backtest, trades_to_dataframe
from core.config import load_config
from core.data_loader import clean_data, load_mt5_csv, load_xauusd_m15
from core.indicators import compute_all
from core.signals import Regime, Signal, SignalEngine


def average_atr_for_idx(df: pd.DataFrame, idx: int) -> float:
    atr_vals = df["atr"].iloc[idx - 23 : idx + 1] if idx >= 23 else df["atr"].iloc[: idx + 1]
    return float(atr_vals.mean()) if len(atr_vals) else 0.0


def build_m5_signals(m15: pd.DataFrame, m5_exec: pd.DataFrame, cfg: dict) -> pd.DataFrame:
    engine = SignalEngine(cfg, df_m5=m5_exec)
    rows = []
    m15_times = m15.index

    for m5_time in m5_exec.index:
        pos = m15_times.searchsorted(m5_time, side="right") - 1
        if pos < 40:
            rows.append((0, 0.0, 0.0, 0.0, ""))
            continue

        atr_avg = average_atr_for_idx(m15, pos)
        if atr_avg <= 0:
            rows.append((0, 0.0, 0.0, 0.0, ""))
            continue

        regime = engine.detect_regime(m15, pos, atr_avg)
        if regime not in (Regime.TREND_UP, Regime.TREND_DOWN):
            rows.append((0, 0.0, 0.0, 0.0, ""))
            continue

        m15_row = m15.iloc[pos]
        if m15_row["adx"] < cfg["intrabar_trend_adx_threshold"]:
            rows.append((0, 0.0, 0.0, 0.0, ""))
            continue

        signal, entry, sl, tp, reason = engine._intrabar_entry_m5_at(
            m15, pos, regime, m15_row["atr"], m5_time
        )
        rows.append((signal.value, entry, sl, tp, reason))

    return pd.DataFrame(rows, columns=["signal", "entry", "sl", "tp", "reason"], index=m5_exec.index)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--start", default="2026-01-01")
    parser.add_argument("--end", default="2026-06-12 23:59:59")
    parser.add_argument("--out", type=Path, default=Path("python/reports/experiments/exp003_m5_intrabar_trades.csv"))
    args = parser.parse_args()

    cfg_all = load_config()
    cfg = cfg_all["strategy"]
    m15 = compute_all(load_xauusd_m15(), cfg).dropna()
    m5 = clean_data(load_mt5_csv(str(Path("python/data/raw/XAUUSD_M5.csv"))))
    m5_exec = m5.loc[args.start : args.end].copy()

    # EA manages stops using M15 ATR while checking on entry-timeframe bars.
    m15_atr = m15["atr"].reindex(m5_exec.index, method="ffill")
    m5_exec["atr"] = m15_atr

    signals = build_m5_signals(m15, m5_exec, cfg)
    result = backtest(
        m5_exec,
        signals,
        cfg,
        initial_capital=cfg_all["backtest"]["initial_capital"],
        fixed_lot=cfg_all["backtest"]["fixed_lot"],
    )

    trades = trades_to_dataframe(result.trades)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    trades.to_csv(args.out, index=False)

    print(f"M5 intrabar backtest: Net {result.net_profit:.2f} / PF {result.profit_factor:.2f} / Trades {result.total_trades}")
    print(f"signals: {int((signals['signal'] != 0).sum())}; wrote trades to {args.out}")
    if not trades.empty:
        print(trades.head(25).to_string(index=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
