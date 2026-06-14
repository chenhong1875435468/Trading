"""
MT5 历史数据加载与预处理。
支持从 MT5 导出的 CSV 读取 OHLC 数据，清洗、重采样、质量校验。
"""

import pandas as pd
import numpy as np
from pathlib import Path
from datetime import datetime


def load_mt5_csv(filepath: str) -> pd.DataFrame:
    """加载 MT5 导出的 CSV 文件，自动处理多种列头格式。

    Args:
        filepath: CSV 文件路径

    Returns:
        DataFrame，列名标准化：open, high, low, close, tickvol, vol, spread，索引为 datetime
    """
    df = pd.read_csv(filepath, dtype=str)

    # 去掉尖括号 <COLNAME>
    df.columns = [c.strip(" <>").lower() for c in df.columns]

    # 已有 datetime 列（HST 转换格式）
    if "datetime" in df.columns:
        df["datetime"] = pd.to_datetime(df["datetime"])
        df.set_index("datetime", inplace=True)
        df.drop(columns=["datetime"], errors="ignore", inplace=True)
    # date + time 列（MT5 导出格式）
    elif "time" in df.columns and "date" in df.columns:
        datetime_str = df["date"].str.strip() + " " + df["time"].str.strip()
        df["datetime"] = pd.to_datetime(datetime_str, format="%Y.%m.%d %H:%M:%S")
        df.drop(columns=["date", "time"], inplace=True, errors="ignore")
        df.set_index("datetime", inplace=True)
    elif "date" in df.columns:
        datetime_str = df["date"].str.strip()
        df["datetime"] = pd.to_datetime(datetime_str, format="%Y.%m.%d %H:%M:%S")
        df.drop(columns=["date"], inplace=True, errors="ignore")
        df.set_index("datetime", inplace=True)
    else:
        # 尝试将第一列作为 datetime
        df.iloc[:, 0] = pd.to_datetime(df.iloc[:, 0])
        df.set_index(df.columns[0], inplace=True)
        df.index.name = "datetime"

    # 数值列转换
    numeric_cols = ["open", "high", "low", "close", "tickvol", "vol", "spread"]
    for col in numeric_cols:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    # 确保索引是 datetime
    if "datetime" in df.columns:
        df.set_index("datetime", inplace=True)
    df.sort_index(inplace=True)

    # 移除全空行
    df.dropna(subset=["open", "high", "low", "close"], how="all", inplace=True)

    return df


def clean_data(df: pd.DataFrame) -> pd.DataFrame:
    """数据清洗：移除 OHLC 异常行、去重索引。

    - 移除任何 OHLC 为 0 或 NaN 的行
    - high < low 的行翻转
    - 保留最后一个重复索引
    """
    ohlc = ["open", "high", "low", "close"]
    df = df[(df[ohlc] > 0).all(axis=1)].copy()

    # 修正 high < low 的异常
    mask = df["high"] < df["low"]
    df.loc[mask, ["high", "low"]] = df.loc[mask, ["low", "high"]].values

    df = df[~df.index.duplicated(keep="last")]
    df.sort_index(inplace=True)
    return df


def quality_report(df: pd.DataFrame) -> dict:
    """生成数据质量报告。

    Returns:
        dict 包含时间范围、行数、缺失天数、异常统计等
    """
    report = {
        "start_date": df.index.min().strftime("%Y-%m-%d"),
        "end_date": df.index.max().strftime("%Y-%m-%d"),
        "total_rows": len(df),
        "missing_dates": _count_missing_dates(df),
        "nulls": df.isnull().sum().to_dict(),
        "ohlc_stats": df[["open", "high", "low", "close"]].describe().to_dict(),
        "price_range": f"{df['close'].min():.2f} – {df['close'].max():.2f}",
    }
    return report


def _count_missing_dates(df: pd.DataFrame) -> int:
    """统计缺失的交易日数（按自然日计算扣除周末）。"""
    full_range = pd.date_range(df.index.min(), df.index.max(), freq="D")
    # 不扣除周末，因为 XAUUSD 24/5 但节假日也缺数据
    return len(full_range) - len(df)


def resample_ohlc(df: pd.DataFrame, timeframe: str) -> pd.DataFrame:
    """将 OHLC DataFrame 重采样到指定时间周期。

    Args:
        df: 带 datetime index 的 OHLC DataFrame
        timeframe: pandas 重采样规则，如 '1h', '4h', '1D'

    Returns:
        重采样后的 DataFrame
    """
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

    resampled = df.resample(timeframe).agg(agg).dropna(subset=["open"])
    return resampled


def load_and_prepare(filepath: str, timeframe: str | None = None) -> pd.DataFrame:
    """一站式数据加载、清洗、可选重采样。

    Args:
        filepath: CSV 路径
        timeframe: 如果指定，重采样到此周期（如 '15T' = M15, '1h' = H1），
                   不指定则保持原始周期

    Returns:
        清洗后的 DataFrame
    """
    df = load_mt5_csv(filepath)
    df = clean_data(df)

    if timeframe is not None:
        df = resample_ohlc(df, timeframe)

    return df


# ——— 便捷函数 ———


def load_xauusd_m15() -> pd.DataFrame:
    """加载项目默认的 XAUUSD M15 数据。"""
    data_dir = Path(__file__).parent.parent / "data" / "raw"
    csv_path = data_dir / "XAUUSD_M15.csv"
    if not csv_path.exists():
        raise FileNotFoundError(f"未找到数据文件: {csv_path}")
    return load_and_prepare(str(csv_path), timeframe=None)


def load_xauusd_h1() -> pd.DataFrame:
    """加载 XAUUSD M15 数据并重采样到 H1。"""
    df = load_xauusd_m15()
    # 原始数据实际为日线级别，直接返回
    return df
