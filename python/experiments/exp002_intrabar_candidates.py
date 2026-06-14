"""Experiment 002: scan M5 intrabar entry candidates against M15 regimes.

This is a diagnostic bridge between the research engine and the EA. The EA can
open on every new M5 bar while using the latest closed M15 snapshot; exp001 only
generated one signal per M15 row, so it misses mid-bar entries.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).parent.parent))

from core.config import load_config
from core.data_loader import clean_data, load_mt5_csv, load_xauusd_m15
from core.indicators import compute_all
from core.signals import Regime, Signal, SignalEngine


def average_atr_for_idx(df: pd.DataFrame, idx: int) -> float:
    atr_vals = df["atr"].iloc[idx - 23 : idx + 1] if idx >= 23 else df["atr"].iloc[: idx + 1]
    return float(atr_vals.mean()) if len(atr_vals) else 0.0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--start", default="2026-01-01")
    parser.add_argument("--end", default="2026-06-12 23:59:59")
    parser.add_argument("--out", type=Path, default=Path("python/reports/experiments/exp002_intrabar_candidates.csv"))
    args = parser.parse_args()

    cfg = load_config()
    m15 = compute_all(load_xauusd_m15(), cfg["strategy"]).dropna()
    m5 = clean_data(load_mt5_csv(str(Path("python/data/raw/XAUUSD_M5.csv"))))

    m15_window = m15.loc[: args.end]
    m5_window = m5.loc[args.start : args.end]
    engine = SignalEngine(cfg["strategy"], df_m5=m5)

    rows: list[dict] = []
    for m5_time in m5_window.index:
        eligible_m15 = m15_window.index[m15_window.index <= m5_time]
        if len(eligible_m15) == 0:
            continue
        m15_time = eligible_m15[-1]
        idx = m15.index.get_loc(m15_time)
        if idx < 40:
            continue

        atr_avg = average_atr_for_idx(m15, idx)
        if atr_avg <= 0:
            continue
        regime = engine.detect_regime(m15, idx, atr_avg)
        if regime not in (Regime.TREND_UP, Regime.TREND_DOWN):
            continue

        row = m15.iloc[idx]
        if row["adx"] < cfg["strategy"]["intrabar_trend_adx_threshold"]:
            continue
        signal, entry, sl, tp, reason = engine._intrabar_entry_m5_at(
            m15, idx, regime, row["atr"], m5_time
        )
        if signal == Signal.NONE:
            continue

        rows.append(
            {
                "entry_time": m5_time,
                "m15_snapshot_time": m15_time,
                "regime": regime.name,
                "signal": "BUY" if signal == Signal.BUY else "SELL",
                "entry": entry,
                "sl": sl,
                "tp": tp,
                "reason": reason,
                "adx": row["adx"],
                "rsi": row["rsi"],
                "atr": row["atr"],
            }
        )

    out = pd.DataFrame(rows)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(args.out, index=False)
    print(f"wrote {len(out)} candidates to {args.out}")
    if not out.empty:
        print(out.head(20).to_string(index=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
