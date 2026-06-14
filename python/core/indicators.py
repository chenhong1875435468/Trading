"""
技术指标计算模块 — 复刻 EA 中使用的所有指标。
所有函数接受 DataFrame/Series，返回 Series 或 DataFrame。
"""

import numpy as np
import pandas as pd


# ——— 移动平均 ———


def ema(series: pd.Series, period: int) -> pd.Series:
    """指数移动平均。"""
    return series.ewm(span=period, adjust=False).mean()


def sma(series: pd.Series, period: int) -> pd.Series:
    """简单移动平均。"""
    return series.rolling(window=period).mean()


# ——— ATR ———


def atr(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """平均真实波幅 (Average True Range)。

    Args:
        df: 含 high, low, close 列的 DataFrame
        period: ATR 周期
    """
    high, low, close = df["high"], df["low"], df["close"]
    prev_close = close.shift(1)

    tr1 = high - low
    tr2 = (high - prev_close).abs()
    tr3 = (low - prev_close).abs()

    true_range = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
    # 使用 EMA 平滑（与 MT5 iATR 一致）
    return true_range.ewm(span=period, adjust=False).mean()


def average_atr(atr_series: pd.Series, start: int, end: int) -> float:
    """计算 ATR 在 [start, end] 范围内的均值（与 EA AverageAtr 对应）。

    Args:
        atr_series: ATR Series（最新的在前面，index=-1 表示最新）
        start: 起始偏移（含）
        end: 结束偏移（含）
    """
    values = atr_series.iloc[start : end + 1]
    return values.mean() if len(values) > 0 else 0.0


# ——— ADX ———


def adx(df: pd.DataFrame, period: int = 14) -> pd.DataFrame:
    """计算 ADX、+DI、-DI。

    Returns:
        DataFrame 包含 adx, plus_di, minus_di 三列
    """
    high, low, close = df["high"], df["low"], df["close"]

    tr1 = high - low
    tr2 = (high - close.shift(1)).abs()
    tr3 = (low - close.shift(1)).abs()
    tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
    atr_series = tr.ewm(span=period, adjust=False).mean()

    up_move = high - high.shift(1)
    down_move = low.shift(1) - low

    plus_dm = np.where((up_move > down_move) & (up_move > 0), up_move, 0.0)
    minus_dm = np.where((down_move > up_move) & (down_move > 0), down_move, 0.0)

    plus_dm = pd.Series(plus_dm, index=df.index)
    minus_dm = pd.Series(minus_dm, index=df.index)

    smoothed_plus_dm = plus_dm.ewm(span=period, adjust=False).mean()
    smoothed_minus_dm = minus_dm.ewm(span=period, adjust=False).mean()

    plus_di = 100.0 * (smoothed_plus_dm / atr_series)
    minus_di = 100.0 * (smoothed_minus_dm / atr_series)

    di_sum = plus_di + minus_di
    dx = 100.0 * ((plus_di - minus_di).abs() / di_sum.replace(0, np.nan))
    adx_series = dx.ewm(span=period, adjust=False).mean()

    return pd.DataFrame(
        {"adx": adx_series, "plus_di": plus_di, "minus_di": minus_di}, index=df.index
    )


# ——— RSI ———


def rsi(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """相对强弱指数 (RSI)，使用 Wilder 平滑方式。"""
    delta = df["close"].diff()
    gain = delta.clip(lower=0)
    loss = (-delta).clip(lower=0)

    avg_gain = gain.ewm(span=period, adjust=False).mean()
    avg_loss = loss.ewm(span=period, adjust=False).mean()

    rs = avg_gain / avg_loss.replace(0, np.nan)
    return 100.0 - (100.0 / (1.0 + rs))


# ——— 布林带 ———


def bollinger_bands(df: pd.DataFrame, period: int = 20, deviation: float = 2.0) -> pd.DataFrame:
    """布林带。

    Returns:
        DataFrame 包含 mid, upper, lower 三列
    """
    mid = sma(df["close"], period)
    std = df["close"].rolling(window=period).std(ddof=1)
    upper = mid + deviation * std
    lower = mid - deviation * std
    return pd.DataFrame({"mid": mid, "upper": upper, "lower": lower}, index=df.index)


# ——— Choppiness Index ———


def choppiness_index(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """波动率/震荡指标 — 判断市场是趋势还是震荡。

    公式：100 * log10( sum(ATR, period) / (max(high, period) - min(low, period)) ) / log10(period)

    高值（>61.8）表示震荡，低值（<38.2）表示趋势。
    """
    atr_series = atr(df, period=1)  # 单周期真实波幅
    sum_tr = atr_series.rolling(window=period).sum()
    period_high = df["high"].rolling(window=period).max()
    period_low = df["low"].rolling(window=period).min()

    range_diff = period_high - period_low
    denominator = range_diff.replace(0, np.nan)

    ratio = sum_tr / denominator
    log_ratio = np.log10(ratio.replace(0, np.nan))
    log_period = np.log10(period)

    choppiness = 100.0 * log_ratio / log_period
    return choppiness.clip(0, 100)


# ——— Efficiency Ratio (Kaufman) ———


def efficiency_ratio(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """价格效率比 — 衡量价格运动的趋势性 vs 噪声。

    公式：abs(close - close[period]) / sum(abs(close - close.shift(1)), period)

    高值接近 1.0 表示强趋势，低值接近 0 表示高噪声。
    """
    direction = (df["close"] - df["close"].shift(period)).abs()
    volatility = (df["close"] - df["close"].shift(1)).abs().rolling(window=period).sum()
    er = direction / volatility.replace(0, np.nan)
    return er


# ——— 摆动高/低点 ———


def swing_highs(series: pd.Series, span: int = 2) -> pd.Series:
    """检测摆动高点 — 当前值高于左右各 span 根 K 线的最高价。

    Returns:
        boolean Series，True 表示该位置是摆动高点
    """
    result = pd.Series(False, index=series.index)
    for i in range(span, len(series) - span):
        window = series.iloc[i - span : i + span + 1]
        if series.iloc[i] == window.max() and list(window).count(window.max()) == 1:
            result.iloc[i] = True
    return result


def swing_lows(series: pd.Series, span: int = 2) -> pd.Series:
    """检测摆动低点 — 当前值低于左右各 span 根 K 线的最低价。"""
    result = pd.Series(False, index=series.index)
    for i in range(span, len(series) - span):
        window = series.iloc[i - span : i + span + 1]
        if series.iloc[i] == window.min() and list(window).count(window.min()) == 1:
            result.iloc[i] = True
    return result


def nearest_swing_high_above(
    df: pd.DataFrame, price: float, start_idx: int, count: int, span: int = 2
) -> float:
    """在指定范围内查找 price 之上的最近摆动高点。

    Args:
        df: 含 high 列的 DataFrame
        price: 下限价格
        start_idx: 起始位置（含）
        count: 搜索范围
        span: 摆动点确认跨度
    Returns:
        最近摆动高点的价格，未找到返回 0.0
    """
    end_idx = min(start_idx + count, len(df) - span)
    swing_mask = swing_highs(df["high"], span)
    nearest = 0.0
    for i in range(max(start_idx, span), end_idx):
        val = df["high"].iloc[i]
        if val >= price and swing_mask.iloc[i]:
            if nearest <= 0.0 or val < nearest:
                nearest = val
    return nearest


def nearest_swing_low_below(
    df: pd.DataFrame, price: float, start_idx: int, count: int, span: int = 2
) -> float:
    """在指定范围内查找 price 之下的最近摆动低点。"""
    end_idx = min(start_idx + count, len(df) - span)
    swing_mask = swing_lows(df["low"], span)
    nearest = 0.0
    for i in range(max(start_idx, span), end_idx):
        val = df["low"].iloc[i]
        if val <= price and swing_mask.iloc[i]:
            if nearest <= 0.0 or val > nearest:
                nearest = val
    return nearest


# ——— SuperTrend ———


def supertrend(df: pd.DataFrame, period: int = 10, multiplier: float = 3.0) -> pd.Series:
    """SuperTrend 指标。

    Returns:
        Series，>0 表示看涨趋势，<0 表示看跌趋势，0 表示中性
    """
    atr_series = atr(df, period)
    hl2 = (df["high"] + df["low"]) / 2.0

    upper_band = hl2 + multiplier * atr_series
    lower_band = hl2 - multiplier * atr_series

    trend = pd.Series(1, index=df.index, dtype=float)  # 1 = bullish, -1 = bearish
    final_upper = pd.Series(np.nan, index=df.index)
    final_lower = pd.Series(np.nan, index=df.index)

    for i in range(1, len(df)):
        # 上轨：当前上轨与上次上轨的最小值（如果在上涨趋势中）
        if df["close"].iloc[i - 1] <= final_upper.iloc[i - 1] or pd.isna(final_upper.iloc[i - 1]):
            final_upper.iloc[i] = upper_band.iloc[i]
        else:
            final_upper.iloc[i] = min(upper_band.iloc[i], final_upper.iloc[i - 1])

        # 下轨：当前下轨与上次下轨的最大值（如果在下跌趋势中）
        if df["close"].iloc[i - 1] >= final_lower.iloc[i - 1] or pd.isna(final_lower.iloc[i - 1]):
            final_lower.iloc[i] = lower_band.iloc[i]
        else:
            final_lower.iloc[i] = max(lower_band.iloc[i], final_lower.iloc[i - 1])

        if df["close"].iloc[i] > final_upper.iloc[i - 1] if not pd.isna(final_upper.iloc[i - 1]) else False:
            trend.iloc[i] = 1
        elif df["close"].iloc[i] < final_lower.iloc[i - 1] if not pd.isna(final_lower.iloc[i - 1]) else False:
            trend.iloc[i] = -1
        else:
            trend.iloc[i] = trend.iloc[i - 1]

    return trend


# ——— VWAP (Session-based) ———


def session_vwap(df: pd.DataFrame) -> pd.Series:
    """基于交易时段的累积 VWAP。
    使用 (H+L+C)/3 作为典型价格，每个自然日重置。
    """
    typical_price = (df["high"] + df["low"] + df["close"]) / 3.0
    # 按日期分组累积
    date_groups = df.index.date
    cumulative_pv = typical_price * df["tickvol"].fillna(0)
    cumsum_pv = pd.Series(index=df.index, dtype=float)
    cumsum_vol = pd.Series(index=df.index, dtype=float)

    for date_val in np.unique(date_groups):
        mask = date_groups == date_val
        cumsum_pv[mask] = cumulative_pv[mask].cumsum()
        cumsum_vol[mask] = df["tickvol"][mask].fillna(0).cumsum()

    vwap = cumsum_pv / cumsum_vol.replace(0, np.nan)
    return vwap


# ——— 区间边界工具 ———


def highest_high(df: pd.DataFrame, start_idx: int, count: int) -> float:
    """指定窗口内的最高价。"""
    return df["high"].iloc[start_idx : start_idx + count].max()


def lowest_low(df: pd.DataFrame, start_idx: int, count: int) -> float:
    """指定窗口内的最低价。"""
    return df["low"].iloc[start_idx : start_idx + count].min()


def count_lower_boundary_touches(
    df: pd.DataFrame, start_idx: int, count: int, range_low: float, buffer: float
) -> int:
    """统计价格触及区间下边界的次数。"""
    end_idx = start_idx + count
    touches = 0
    for i in range(start_idx, min(end_idx, len(df))):
        if df["low"].iloc[i] <= range_low + buffer and df["close"].iloc[i] >= range_low:
            touches += 1
    return touches


def count_upper_boundary_touches(
    df: pd.DataFrame, start_idx: int, count: int, range_high: float, buffer: float
) -> int:
    """统计价格触及区间上边界的次数。"""
    end_idx = start_idx + count
    touches = 0
    for i in range(start_idx, min(end_idx, len(df))):
        if df["high"].iloc[i] >= range_high - buffer and df["close"].iloc[i] <= range_high:
            touches += 1
    return touches


# ——— K线形态 ———


def is_bullish_rejection(row: pd.Series) -> bool:
    """判断看涨拒绝K线 — 下影线长、实体在上部。"""
    bar_range = row["high"] - row["low"]
    if bar_range <= 0:
        return False
    lower_wick = min(row["open"], row["close"]) - row["low"]
    body = abs(row["close"] - row["open"])
    return lower_wick >= body * 1.5 and row["close"] >= row["open"]


def is_bearish_rejection(row: pd.Series) -> bool:
    """判断看跌拒绝K线 — 上影线长、实体在下部。"""
    bar_range = row["high"] - row["low"]
    if bar_range <= 0:
        return False
    upper_wick = row["high"] - max(row["open"], row["close"])
    body = abs(row["close"] - row["open"])
    return upper_wick >= body * 1.5 and row["close"] <= row["open"]


# ——— 批量计算所有指标 ———


def compute_all(df: pd.DataFrame, config: dict) -> pd.DataFrame:
    """根据配置字典计算所有指标并追加到 DataFrame。

    Args:
        df: OHLC DataFrame
        config: strategy 配置字典（来自 config.yaml 的 strategy 部分）

    Returns:
        追加了指标列的新 DataFrame
    """
    result = df.copy()

    # EMA
    result["ema_fast"] = ema(result["close"], config["fast_ema_period"])
    result["ema_slow"] = ema(result["close"], config["slow_ema_period"])
    result["ema_200"] = ema(result["close"], 200)

    # ADX
    adx_df = adx(result, config["adx_period"])
    result["adx"] = adx_df["adx"]
    result["plus_di"] = adx_df["plus_di"]
    result["minus_di"] = adx_df["minus_di"]

    # ATR
    result["atr"] = atr(result, config["atr_period"])

    # RSI
    result["rsi"] = rsi(result, config["rsi_period"])

    # 布林带
    bb = bollinger_bands(result, config["bands_period"], config["bands_deviation"])
    result["bb_mid"] = bb["mid"]
    result["bb_upper"] = bb["upper"]
    result["bb_lower"] = bb["lower"]

    # Choppiness
    result["choppiness"] = choppiness_index(result, config["choppiness_period"])

    # Efficiency Ratio
    result["efficiency"] = efficiency_ratio(result, config["efficiency_period"])

    # SuperTrend
    result["supertrend"] = supertrend(
        result, config["supertrend_period"], config["supertrend_multiplier"]
    )

    # VWAP
    result["vwap"] = session_vwap(result)

    # 派生列
    result["ema_gap_atr"] = (result["ema_fast"] - result["ema_slow"]).abs() / result["atr"]
    result["di_gap"] = (result["plus_di"] - result["minus_di"]).abs()
    result["vwap_deviation_atr"] = (result["close"] - result["vwap"]) / result["atr"]
    result["trend_distance_atr"] = (result["close"] - result["ema_fast"]).abs() / result["atr"]

    return result
