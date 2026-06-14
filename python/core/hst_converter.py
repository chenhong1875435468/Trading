"""
MT5 HST 历史数据文件 → CSV 转换工具。

HST 文件格式（MT5 Build 400+, 每条记录 60 字节）:
    头部: 148 字节（version, copyright, symbol, period, digits, ...）
    Bar:  60 字节/条（ctm, open, low, high, close, tick_volume, spread, real_volume）

用法:
    python core/hst_converter.py <input.hst> [output.csv] [target_timeframe]
"""

import struct
import sys
import pandas as pd
from pathlib import Path
from datetime import datetime, timezone


def read_hst_bars(filepath: str) -> list[dict]:
    """读取 MT5 HST 文件，返回 Bar 列表。"""
    with open(filepath, "rb") as f:
        data = f.read()

    if len(data) < 148:
        raise ValueError(f"文件太小 ({len(data)} 字节)，不是有效的 HST 文件")

    # 解析头部
    version = struct.unpack_from("<I", data, 0)[0]
    copyright_bytes = struct.unpack_from("<64s", data, 4)[0]
    symbol = struct.unpack_from("<12s", data, 68)[0].decode("utf-8").rstrip("\x00")
    period = struct.unpack_from("<I", data, 80)[0]
    digits = struct.unpack_from("<I", data, 84)[0]

    print(f"HST 版本: {version}")
    print(f"品种: {symbol}")
    print(f"周期: {period} 分钟")
    print(f"小数位: {digits}")

    header_size = 148
    bar_size = 60
    body_size = len(data) - header_size
    num_bars = body_size // bar_size

    if body_size % bar_size != 0:
        print(f"警告: 文件体大小 {body_size} 不是 60 的整数倍，可能有截断")

    print(f"Bar 总数: {num_bars}")

    bars = []
    for i in range(num_bars):
        offset = header_size + i * bar_size
        ctm, open_p, low, high, close_p, tick_vol, spread, real_vol = struct.unpack_from(
            "<qddddq i q", data, offset
        )
        bars.append({
            "datetime": datetime.fromtimestamp(ctm, tz=timezone.utc),
            "open": round(open_p, digits),
            "high": round(high, digits),
            "low": round(low, digits),
            "close": round(close_p, digits),
            "tickvol": tick_vol,
            "spread": spread,
            "vol": real_vol,
        })

    return bars, symbol, period


def bars_to_dataframe(bars: list[dict]) -> pd.DataFrame:
    """Bar 列表转 DataFrame。"""
    df = pd.DataFrame(bars)
    df.set_index("datetime", inplace=True)
    df.sort_index(inplace=True)
    return df


def resample_to_timeframe(df: pd.DataFrame, target_minutes: int) -> pd.DataFrame:
    """将 OHLC 数据重采样到目标周期。

    Args:
        df: 原始 OHLC DataFrame
        target_minutes: 目标周期（分钟）
    """
    freq_map = {
        1: "1min", 5: "5min", 15: "15min", 30: "30min",
        60: "1h", 240: "4h", 1440: "1D", 10080: "1W",
    }
    freq = freq_map.get(target_minutes, f"{target_minutes}min")

    agg = {
        "open": "first",
        "high": "max",
        "low": "min",
        "close": "last",
    }
    if "tickvol" in df.columns:
        agg["tickvol"] = "sum"
    if "vol" in df.columns:
        agg["vol"] = "sum"
    if "spread" in df.columns:
        agg["spread"] = "mean"

    resampled = df.resample(freq).agg(agg).dropna(subset=["open"])
    return resampled


def hst_to_csv(hst_path: str, target_timeframe: int = 15) -> pd.DataFrame:
    """一站式 HST → DataFrame（含重采样到目标周期）。

    Args:
        hst_path: HST 文件路径
        target_timeframe: 目标周期（分钟），默认 15 (M15)

    Returns:
        DataFrame，同时保存 CSV
    """
    bars, symbol, source_period = read_hst_bars(hst_path)
    df = bars_to_dataframe(bars)

    print(f"数据范围: {df.index.min()} → {df.index.max()}")

    if target_timeframe > source_period:
        print(f"重采样: M{source_period} → M{target_timeframe}")
        df = resample_to_timeframe(df, target_timeframe)
        print(f"重采样后行数: {len(df)}")

    # 保存 CSV
    output_dir = Path(hst_path).parent
    output_name = f"{symbol}_M{target_timeframe}.csv"
    output_path = output_dir / output_name
    df.to_csv(output_path)
    print(f"已保存: {output_path}")

    return df


def main():
    if len(sys.argv) < 2:
        print("用法: python hst_converter.py <input.hst> [target_timeframe]")
        print("  target_timeframe: 目标周期（分钟），默认 15")
        print("  输出文件保存在同目录下")
        sys.exit(1)

    hst_path = sys.argv[1]
    target_tf = int(sys.argv[2]) if len(sys.argv) > 2 else 15

    if not Path(hst_path).exists():
        print(f"文件不存在: {hst_path}")
        sys.exit(1)

    hst_to_csv(hst_path, target_tf)


if __name__ == "__main__":
    main()
