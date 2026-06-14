"""Reconcile Python backtest trades against an MT5 Strategy Tester HTML report.

This intentionally uses only the Python standard library plus pandas so it can run
in the current project environment without lxml/html5lib.
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from html import unescape
from html.parser import HTMLParser
from pathlib import Path

import pandas as pd


@dataclass
class HtmlRow:
    cells: list[str]


class TableRowParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.rows: list[HtmlRow] = []
        self._in_tr = False
        self._in_cell = False
        self._current_cells: list[str] = []
        self._current_text: list[str] = []

    def handle_starttag(self, tag: str, attrs) -> None:
        if tag.lower() == "tr":
            self._in_tr = True
            self._current_cells = []
        elif tag.lower() in ("td", "th") and self._in_tr:
            self._in_cell = True
            self._current_text = []

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        if tag in ("td", "th") and self._in_cell:
            text = " ".join("".join(self._current_text).split())
            self._current_cells.append(text)
            self._in_cell = False
        elif tag == "tr" and self._in_tr:
            if self._current_cells:
                self.rows.append(HtmlRow(self._current_cells))
            self._in_tr = False

    def handle_data(self, data: str) -> None:
        if self._in_cell:
            self._current_text.append(data)


def parse_html_rows(path: Path) -> list[list[str]]:
    raw = path.read_bytes()
    if b"\x00" in raw[:200]:
        try:
            text = raw.decode("utf-16")
        except UnicodeError:
            text = raw.replace(b"\x00", b"").decode("utf-8", errors="ignore")
    else:
        text = raw.decode("utf-8", errors="ignore")
    rows: list[list[str]] = []
    for tr in re.findall(r"<tr\b[^>]*>(.*?)</tr>", text, flags=re.IGNORECASE | re.DOTALL):
        cells = []
        for cell in re.findall(r"<t[dh]\b[^>]*>(.*?)</t[dh]>", tr, flags=re.IGNORECASE | re.DOTALL):
            clean = re.sub(r"<[^>]+>", "", cell)
            clean = " ".join(unescape(clean).split())
            cells.append(clean)
        if cells:
            rows.append(cells)
    if rows:
        return rows

    parser = TableRowParser()
    parser.feed(text)
    return [row.cells for row in parser.rows]


def extract_section(rows: list[list[str]], section_name: str) -> pd.DataFrame:
    section_start = None
    for i, row in enumerate(rows):
        if any(cell.strip().lower() == section_name.lower() for cell in row):
            section_start = i
            break
    if section_start is None:
        return pd.DataFrame()

    header = None
    data: list[list[str]] = []
    for row in rows[section_start + 1 :]:
        if any(cell in {"Orders", "Deals"} and cell != section_name for cell in row):
            break
        if not header and any(cell in {"Time", "Open Time"} for cell in row):
            header = row
            continue
        if header and len(row) == len(header):
            data.append(row)

    if not header:
        return pd.DataFrame()
    return pd.DataFrame(data, columns=header)


def to_float(value: object) -> float:
    if value is None:
        return 0.0
    text = str(value).replace(" ", "").replace(",", "")
    if text == "":
        return 0.0
    try:
        return float(text)
    except ValueError:
        return 0.0


def mt5_deals_to_trades(deals: pd.DataFrame) -> pd.DataFrame:
    if deals.empty:
        return pd.DataFrame()

    normalized = deals.copy()
    normalized.columns = [
        "time",
        "deal",
        "symbol",
        "type",
        "direction",
        "volume",
        "price",
        "order",
        "commission",
        "swap",
        "profit",
        "balance",
        "comment",
    ][: len(normalized.columns)]

    active: list[dict] = []
    trades: list[dict] = []
    for _, row in normalized.iterrows():
        deal_type = str(row.get("type", "")).lower()
        direction = str(row.get("direction", "")).lower()
        if deal_type == "balance" or row.get("symbol", "") == "":
            continue

        time = pd.to_datetime(row["time"], format="%Y.%m.%d %H:%M:%S", errors="coerce")
        if pd.isna(time):
            continue

        if direction == "in":
            active.append(
                {
                    "entry_time": time,
                    "direction": "BUY" if deal_type == "buy" else "SELL",
                    "entry": to_float(row.get("price")),
                    "entry_deal": row.get("deal", ""),
                    "entry_comment": row.get("comment", ""),
                }
            )
        elif direction == "out":
            if not active:
                continue
            trade = active.pop(0)
            trade.update(
                {
                    "exit_time": time,
                    "exit": to_float(row.get("price")),
                    "exit_deal": row.get("deal", ""),
                    "profit": to_float(row.get("profit")),
                    "exit_comment": row.get("comment", ""),
                }
            )
            trades.append(trade)

    return pd.DataFrame(trades)


def load_python_trades(
    path: Path, start: str | None, end: str | None, time_offset_hours: float
) -> pd.DataFrame:
    df = pd.read_csv(path)
    if df.empty:
        return df
    df["entry_time"] = pd.to_datetime(df["entry_time"], errors="coerce")
    df["exit_time"] = pd.to_datetime(df["exit_time"], errors="coerce")
    if time_offset_hours:
        offset = pd.Timedelta(hours=time_offset_hours)
        df["entry_time"] = df["entry_time"] + offset
        df["exit_time"] = df["exit_time"] + offset
    if start:
        df = df[df["entry_time"] >= pd.Timestamp(start)]
    if end:
        df = df[df["entry_time"] <= pd.Timestamp(end)]
    return df.reset_index(drop=True)


def nearest_reconciliation(mt5: pd.DataFrame, py: pd.DataFrame) -> pd.DataFrame:
    rows: list[dict] = []
    for idx, mt5_row in mt5.iterrows():
        candidates = py[py["direction"].str.upper() == mt5_row["direction"]]
        if candidates.empty:
            candidates = py
        if candidates.empty:
            rows.append({"mt5_index": idx + 1, "match_status": "no_python_trades"})
            continue
        deltas = (candidates["entry_time"] - mt5_row["entry_time"]).abs()
        py_idx = deltas.idxmin()
        py_row = candidates.loc[py_idx]
        delta_minutes = abs((py_row["entry_time"] - mt5_row["entry_time"]).total_seconds()) / 60.0
        rows.append(
            {
                "mt5_index": idx + 1,
                "python_index": int(py_idx) + 1,
                "delta_minutes": round(delta_minutes, 2),
                "mt5_entry_time": mt5_row["entry_time"],
                "python_entry_time": py_row["entry_time"],
                "mt5_direction": mt5_row["direction"],
                "python_direction": py_row["direction"],
                "mt5_entry": mt5_row["entry"],
                "python_entry": py_row["entry"],
                "entry_diff": round(to_float(py_row["entry"]) - to_float(mt5_row["entry"]), 2),
                "mt5_exit_time": mt5_row["exit_time"],
                "python_exit_time": py_row["exit_time"],
                "mt5_exit": mt5_row["exit"],
                "python_exit": py_row["exit"],
                "mt5_profit": mt5_row["profit"],
                "python_profit": py_row["profit"],
                "mt5_entry_comment": mt5_row.get("entry_comment", ""),
                "mt5_exit_comment": mt5_row.get("exit_comment", ""),
                "python_reason": py_row.get("reason", ""),
            }
        )
    return pd.DataFrame(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mt5-report", type=Path, required=True)
    parser.add_argument("--python-trades", type=Path, default=Path("python/reports/experiments/exp001_trades.csv"))
    parser.add_argument("--start", default=None)
    parser.add_argument("--end", default=None)
    parser.add_argument(
        "--python-time-offset-hours",
        type=float,
        default=0.0,
        help="Offset applied to Python trade timestamps before comparison. Use -8 when Python data was written as UTC+8 and MT5 reports are server time.",
    )
    parser.add_argument("--out-dir", type=Path, default=Path("python/reports/reconciliation"))
    args = parser.parse_args()

    rows = parse_html_rows(args.mt5_report)
    deals = extract_section(rows, "Deals")
    orders = extract_section(rows, "Orders")
    mt5_trades = mt5_deals_to_trades(deals)
    py_trades = load_python_trades(
        args.python_trades, args.start, args.end, args.python_time_offset_hours
    )
    comparison = nearest_reconciliation(mt5_trades, py_trades)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    stem = args.mt5_report.stem
    deals_path = args.out_dir / f"{stem}_deals.csv"
    orders_path = args.out_dir / f"{stem}_orders.csv"
    mt5_trades_path = args.out_dir / f"{stem}_mt5_trades.csv"
    comparison_path = args.out_dir / f"{stem}_comparison.csv"
    summary_path = args.out_dir / f"{stem}_summary.json"

    deals.to_csv(deals_path, index=False)
    orders.to_csv(orders_path, index=False)
    mt5_trades.to_csv(mt5_trades_path, index=False)
    comparison.to_csv(comparison_path, index=False)

    summary = {
        "mt5_report": str(args.mt5_report),
        "python_trades": str(args.python_trades),
        "start": args.start,
        "end": args.end,
        "python_time_offset_hours": args.python_time_offset_hours,
        "orders": len(orders),
        "deals": len(deals),
        "mt5_trades": len(mt5_trades),
        "python_trades_in_window": len(py_trades),
        "median_entry_delta_minutes": (
            float(comparison["delta_minutes"].median()) if "delta_minutes" in comparison else None
        ),
        "max_entry_delta_minutes": (
            float(comparison["delta_minutes"].max()) if "delta_minutes" in comparison else None
        ),
        "outputs": {
            "deals": str(deals_path),
            "orders": str(orders_path),
            "mt5_trades": str(mt5_trades_path),
            "comparison": str(comparison_path),
        },
    }
    summary_path.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
