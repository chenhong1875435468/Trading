"""Analyze MT5 Strategy Tester trades against market features.

Purpose:
    Use MT5 as the source of truth for executed trades, then let Python explain
    which market features are associated with profit/loss. This supports EA
    parameter and filter research without treating Python backtests as final
    validation.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import pandas as pd

PYTHON_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PYTHON_ROOT))
sys.path.insert(0, str(PYTHON_ROOT / "tools"))

from core.config import load_config
from core.data_loader import load_xauusd_m15
from core.indicators import compute_all
from reconcile_mt5_python import extract_section, mt5_deals_to_trades, parse_html_rows


FEATURE_COLUMNS = [
    "adx",
    "rsi",
    "atr",
    "choppiness",
    "efficiency",
    "ema_gap_atr",
    "di_gap",
    "vwap_deviation_atr",
    "trend_distance_atr",
]


def discover_reports(root: Path, suite: str) -> list[Path]:
    return sorted(root.glob(f"{suite}_*/*_report.htm"))


def split_from_report_path(path: Path) -> str:
    text = path.parent.name
    for split in ("train", "test", "valid"):
        if f"_{split}_" in text or text.endswith(f"_{split}"):
            return split
    return "unknown"


def load_mt5_trades(report_path: Path) -> pd.DataFrame:
    rows = parse_html_rows(report_path)
    deals = extract_section(rows, "Deals")
    trades = mt5_deals_to_trades(deals)
    if trades.empty:
        return trades
    trades["report"] = str(report_path)
    trades["split"] = split_from_report_path(report_path)
    trades["is_grid"] = trades["entry_comment"].str.contains("Grid", case=False, na=False)
    trades["is_trend"] = trades["entry_comment"].str.contains("Trend", case=False, na=False)
    return trades


def nearest_prior_row(df: pd.DataFrame, timestamp: pd.Timestamp) -> pd.Series | None:
    pos = df.index.searchsorted(timestamp, side="right") - 1
    if pos < 0:
        return None
    return df.iloc[pos]


def enrich_trades(
    trades: pd.DataFrame,
    features: pd.DataFrame,
    mt5_to_data_offset_hours: float,
) -> pd.DataFrame:
    rows: list[dict] = []
    offset = pd.Timedelta(hours=mt5_to_data_offset_hours)

    for _, trade in trades.iterrows():
        entry_time = pd.Timestamp(trade["entry_time"])
        feature_time = entry_time + offset
        feat = nearest_prior_row(features, feature_time)
        if feat is None:
            continue

        row = trade.to_dict()
        row["feature_time"] = feature_time
        row["entry_hour"] = entry_time.hour
        row["entry_weekday"] = entry_time.day_name()
        row["profit_positive"] = float(row.get("profit", 0.0)) > 0
        row["side"] = row.get("direction", "")
        row["setup"] = "grid" if row.get("is_grid") else ("trend" if row.get("is_trend") else "other")

        for col in FEATURE_COLUMNS:
            row[col] = float(feat.get(col, 0.0))
        row["higher_ema_up"] = bool(feat.get("higher_ema_up", False))
        row["higher_ema_down"] = bool(feat.get("higher_ema_down", False))
        rows.append(row)

    return pd.DataFrame(rows)


def summarize_group(df: pd.DataFrame, by: str) -> pd.DataFrame:
    if df.empty or by not in df.columns:
        return pd.DataFrame()
    grouped = df.groupby(by, dropna=False)
    out = grouped.agg(
        trades=("profit", "size"),
        net=("profit", "sum"),
        avg_profit=("profit", "mean"),
        win_rate=("profit_positive", "mean"),
        avg_adx=("adx", "mean"),
        avg_rsi=("rsi", "mean"),
        avg_atr=("atr", "mean"),
        avg_choppiness=("choppiness", "mean"),
        avg_efficiency=("efficiency", "mean"),
    ).reset_index()
    out["win_rate"] = out["win_rate"] * 100.0
    return out.sort_values(["net", "trades"], ascending=[False, False])


def bin_feature(df: pd.DataFrame, feature: str, bins: list[float]) -> pd.DataFrame:
    work = df.copy()
    work[f"{feature}_bin"] = pd.cut(work[feature], bins=bins, include_lowest=True)
    return summarize_group(work, f"{feature}_bin")


def markdown_table(df: pd.DataFrame, max_rows: int = 12) -> str:
    if df.empty:
        return "_No data._"
    view = df.head(max_rows).copy()
    for col in view.columns:
        if pd.api.types.is_float_dtype(view[col]):
            view[col] = view[col].map(lambda value: f"{value:.2f}")
        else:
            view[col] = view[col].astype(str)
    headers = list(view.columns)
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join(["---"] * len(headers)) + " |",
    ]
    for _, row in view.iterrows():
        lines.append("| " + " | ".join(str(row[col]) for col in headers) + " |")
    return "\n".join(lines)


def write_report(
    enriched: pd.DataFrame,
    outputs: dict[str, Path],
    suite: str,
    mt5_to_data_offset_hours: float,
) -> None:
    split_summary = summarize_group(enriched, "split")
    setup_summary = summarize_group(enriched, "setup")
    side_summary = summarize_group(enriched, "side")
    hour_summary = summarize_group(enriched, "entry_hour")
    weekday_summary = summarize_group(enriched, "entry_weekday")
    adx_bins = bin_feature(enriched, "adx", [0, 24, 28, 32, 40, 100])
    rsi_bins = bin_feature(enriched, "rsi", [0, 28, 32, 38, 45, 55, 100])
    atr_bins = bin_feature(enriched, "atr", [0, 8, 12, 18, 28, 45, 1000])
    choppy_bins = bin_feature(enriched, "choppiness", [0, 35, 45, 55, 65, 100])
    eff_bins = bin_feature(enriched, "efficiency", [0, 0.25, 0.34, 0.45, 0.6, 1.0])

    lines = [
        f"# MT5 Trade Feature Analysis - {suite}",
        "",
        "MT5 Strategy Tester trades are used as the source of truth. Python only enriches those trades with market features at entry time.",
        "",
        f"- Trades analyzed: `{len(enriched)}`",
        f"- MT5-to-data timestamp offset: `{mt5_to_data_offset_hours}` hours",
        f"- Enriched trades CSV: `{outputs['enriched']}`",
        "",
        "## Split Summary",
        markdown_table(split_summary),
        "",
        "## Setup Summary",
        markdown_table(setup_summary),
        "",
        "## Direction Summary",
        markdown_table(side_summary),
        "",
        "## Entry Hour Summary",
        markdown_table(hour_summary, 24),
        "",
        "## Weekday Summary",
        markdown_table(weekday_summary),
        "",
        "## Feature Bins",
        "",
        "### ADX",
        markdown_table(adx_bins),
        "",
        "### RSI",
        markdown_table(rsi_bins),
        "",
        "### ATR",
        markdown_table(atr_bins),
        "",
        "### Choppiness",
        markdown_table(choppy_bins),
        "",
        "### Efficiency",
        markdown_table(eff_bins),
        "",
        "## Research Notes",
        "",
        "- Treat these as hypotheses for EA filters/parameters, not as final validation.",
        "- Validate any proposed filter in MT5 train/test/valid and rolling windows.",
        "- Current M5 history starts later than M15 history, so older intrabar-level analysis remains limited until deeper M5 history is downloaded.",
        "",
    ]
    outputs["report"].write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", default="baseline_m15_aligned")
    parser.add_argument("--mt5-runs-dir", type=Path, default=Path("python/reports/mt5_runs"))
    parser.add_argument("--out-dir", type=Path, default=Path("python/reports/analysis"))
    parser.add_argument(
        "--mt5-to-data-offset-hours",
        type=float,
        default=8.0,
        help="Project CSV timestamps are currently MT5 report/server time plus this offset.",
    )
    args = parser.parse_args()

    reports = discover_reports(args.mt5_runs_dir, args.suite)
    if not reports:
        raise FileNotFoundError(f"No MT5 reports found for suite {args.suite} under {args.mt5_runs_dir}")

    cfg = load_config()
    features = compute_all(load_xauusd_m15(), cfg["strategy"]).dropna()

    trades = []
    for report in reports:
        parsed = load_mt5_trades(report)
        if not parsed.empty:
            trades.append(parsed)
    if not trades:
        raise RuntimeError("No MT5 trades parsed from reports")

    all_trades = pd.concat(trades, ignore_index=True)
    enriched = enrich_trades(all_trades, features, args.mt5_to_data_offset_hours)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    outputs = {
        "raw_trades": args.out_dir / f"{args.suite}_mt5_trades.csv",
        "enriched": args.out_dir / f"{args.suite}_trade_features.csv",
        "report": args.out_dir / f"{args.suite}_feature_analysis.md",
    }
    all_trades.to_csv(outputs["raw_trades"], index=False)
    enriched.to_csv(outputs["enriched"], index=False)
    write_report(enriched, outputs, args.suite, args.mt5_to_data_offset_hours)

    print(f"parsed {len(all_trades)} MT5 trades from {len(reports)} reports")
    print(f"wrote {outputs['enriched']}")
    print(f"wrote {outputs['report']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
