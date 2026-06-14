"""Sync OHLC history from a running MetaTrader 5 terminal.

Example:
    py python/tools/sync_mt5_history.py --symbol XAUUSD --timeframes M15 M5 --from 2023-01-01
"""

from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
from pathlib import Path

import MetaTrader5 as mt5
import pandas as pd


TIMEFRAMES = {
    "M1": mt5.TIMEFRAME_M1,
    "M5": mt5.TIMEFRAME_M5,
    "M15": mt5.TIMEFRAME_M15,
    "M30": mt5.TIMEFRAME_M30,
    "H1": mt5.TIMEFRAME_H1,
    "H4": mt5.TIMEFRAME_H4,
    "D1": mt5.TIMEFRAME_D1,
}

CHUNK_DAYS = {
    "M1": 14,
    "M5": 60,
    "M15": 180,
    "M30": 365,
    "H1": 730,
    "H4": 1460,
    "D1": 3650,
}


def parse_date(value: str) -> datetime:
    for fmt in ("%Y-%m-%d", "%Y.%m.%d", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(value, fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    raise argparse.ArgumentTypeError(f"Unsupported date format: {value}")


def rates_to_dataframe(rates, time_offset_hours: int = 8) -> pd.DataFrame:
    df = pd.DataFrame(rates)
    if df.empty:
        return df

    df["datetime"] = pd.to_datetime(df["time"], unit="s") + pd.Timedelta(hours=time_offset_hours)
    df.rename(columns={"tick_volume": "tickvol", "real_volume": "vol"}, inplace=True)
    cols = ["datetime", "open", "high", "low", "close", "tickvol", "spread", "vol"]
    return df[cols]


def fetch_rates_in_chunks(
    symbol: str,
    timeframe: str,
    start: datetime,
    end: datetime,
    time_offset_hours: int,
) -> pd.DataFrame:
    frames: list[pd.DataFrame] = []
    step = timedelta(days=CHUNK_DAYS[timeframe])
    chunk_start = start

    while chunk_start < end:
        chunk_end = min(chunk_start + step, end)
        rates = mt5.copy_rates_range(symbol, TIMEFRAMES[timeframe], chunk_start, chunk_end)
        if rates is None:
            raise RuntimeError(
                f"MT5 returned no data for {symbol} {timeframe} "
                f"{chunk_start} -> {chunk_end}: {mt5.last_error()}"
            )

        df = rates_to_dataframe(rates, time_offset_hours=time_offset_hours)
        if not df.empty:
            frames.append(df)

        chunk_start = chunk_end

    if not frames:
        return pd.DataFrame()

    df_all = pd.concat(frames, ignore_index=True)
    df_all = df_all.drop_duplicates(subset=["datetime"]).sort_values("datetime").reset_index(drop=True)
    return df_all


def sync_timeframe(
    symbol: str,
    timeframe: str,
    start: datetime,
    end: datetime,
    output_dir: Path,
    time_offset_hours: int,
) -> Path:
    df = fetch_rates_in_chunks(symbol, timeframe, start, end, time_offset_hours)

    if df.empty:
        raise RuntimeError(f"MT5 returned an empty dataset for {symbol} {timeframe}")

    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"{symbol}_{timeframe}.csv"
    df.to_csv(output_path, index=False)

    first = df["datetime"].iloc[0]
    last = df["datetime"].iloc[-1]
    print(f"{timeframe}: wrote {len(df)} rows to {output_path} ({first} -> {last})")
    requested_start = pd.Timestamp(start).tz_localize(None) + pd.Timedelta(hours=time_offset_hours)
    first_ts = pd.Timestamp(first)
    if first_ts > requested_start + pd.Timedelta(days=1):
        print(
            f"WARNING: {timeframe} history starts after requested range. "
            "Increase MT5 'Max bars in chart' and download more history if this timeframe "
            "is needed for older backtests."
        )
    return output_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--symbol", default="XAUUSD")
    parser.add_argument("--timeframes", nargs="+", default=["M15", "M5"], choices=sorted(TIMEFRAMES))
    parser.add_argument("--from", dest="start", type=parse_date, default=parse_date("2023-01-01"))
    parser.add_argument("--to", dest="end", type=parse_date, default=None)
    parser.add_argument("--terminal", default=r"C:\Program Files\MetaTrader 5\terminal64.exe")
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parents[1] / "data" / "raw")
    parser.add_argument(
        "--time-offset-hours",
        type=int,
        default=8,
        help="Hours added to MT5 UTC timestamps before writing CSV. Existing project CSVs use UTC+8.",
    )
    args = parser.parse_args()

    end = args.end or (datetime.now(timezone.utc) + timedelta(days=1))

    if not mt5.initialize(path=args.terminal):
        raise RuntimeError(f"Could not initialize MT5: {mt5.last_error()}")

    try:
        if not mt5.symbol_select(args.symbol, True):
            raise RuntimeError(f"Could not select symbol {args.symbol}: {mt5.last_error()}")

        info = mt5.account_info()
        version = mt5.version()
        print(f"Connected to MT5 {version}; account={info.login if info else 'unknown'}; symbol={args.symbol}")

        for timeframe in args.timeframes:
            sync_timeframe(args.symbol, timeframe, args.start, end, args.output_dir, args.time_offset_hours)
    finally:
        mt5.shutdown()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
