"""
交易信号引擎 — 将 EA v7.1 的趋势+震荡双模式策略逻辑从 MQL5 翻译为 Python。

核心流程：
    1. detect_regime()     — 行情状态识别（趋势上涨/趋势下跌/震荡/不明确）
    2. generate_signal()   — 根据行情状态生成入场信号
    3. calculate_sl_tp()   — 计算止损止盈价格
"""

import numpy as np
import pandas as pd
from enum import Enum

from .indicators import (
    highest_high, lowest_low, count_lower_boundary_touches,
    count_upper_boundary_touches, is_bullish_rejection, is_bearish_rejection,
    average_atr, nearest_swing_high_above, nearest_swing_low_below,
)


class Regime(Enum):
    UNKNOWN = 0
    TREND_UP = 1
    TREND_DOWN = 2
    RANGE = 3


class Signal(Enum):
    NONE = 0
    BUY = 1
    SELL = 2


class StrategySnapshot:
    """单次策略快照 — 对应 EA 的 StrategySnapshot 结构体。"""

    def __init__(self):
        self.regime = Regime.UNKNOWN
        self.signal = Signal.NONE
        self.entry = 0.0
        self.sl = 0.0
        self.tp = 0.0
        self.adx = 0.0
        self.rsi = 0.0
        self.atr = 0.0
        self.choppiness = 0.0
        self.efficiency = 0.0
        self.ema_fast = 0.0
        self.ema_slow = 0.0
        self.bands_mid = 0.0
        self.bands_upper = 0.0
        self.bands_lower = 0.0
        self.vwap_deviation_atr = 0.0
        self.higher_trend = 0
        self.reason = "No clear setup"


class SignalEngine:
    """策略信号引擎 — 封装所有 EA 策略逻辑。

    Args:
        config: strategy 参数字典（来自 config.yaml）
        df_m5: 可选 M5 数据用于 Intrabar 精确入场
    """

    def __init__(self, config: dict, df_m5: pd.DataFrame | None = None):
        self.cfg = config
        self.df_m5 = df_m5

    # ——— 行情状态识别 ———

    def detect_regime(self, df: pd.DataFrame, idx: int, atr_avg: float) -> Regime:
        """判断当前 K 线的行情状态。

        Args:
            df: 含所有指标列的 DataFrame
            idx: 当前 K 线位置（iloc 索引）
            atr_avg: ATR 平均值（atr[2] 到 atr[24] 的均值）

        Returns:
            Regime 枚举值
        """
        if idx < 2:
            return Regime.UNKNOWN

        cfg = self.cfg
        row = df.iloc[idx]
        prev = df.iloc[idx - 1]
        prev2 = df.iloc[idx - 2]
        prev3 = df.iloc[idx - 3]

        # EMA 方向
        ema_up = (
            row["ema_fast"] > row["ema_slow"]
            and row["ema_fast"] > prev2["ema_fast"]
            and row["ema_slow"] >= prev3["ema_slow"]
        )
        ema_down = (
            row["ema_fast"] < row["ema_slow"]
            and row["ema_fast"] < prev2["ema_fast"]
            and row["ema_slow"] <= prev3["ema_slow"]
        )

        # ATR 活跃度
        atr_active = row["atr"] >= atr_avg * cfg["min_atr_factor"]

        # 布林带中轨
        close_above_mid = row["close"] > row["bb_mid"]
        close_below_mid = row["close"] < row["bb_mid"]

        # DI 方向
        di_gap = row["di_gap"]
        di_bullish = (
            row["plus_di"] > row["minus_di"]
            and row["plus_di"] >= df.iloc[idx - 1]["plus_di"]
            and row["plus_di"] - row["minus_di"] >= cfg["min_trend_di_gap"]
        )
        di_bearish = (
            row["minus_di"] > row["plus_di"]
            and row["minus_di"] >= df.iloc[idx - 1]["minus_di"]
            and row["minus_di"] - row["plus_di"] >= cfg["min_trend_di_gap"]
        )

        # EMA 间距 / ATR
        ema_gap_atr = row["ema_gap_atr"]

        # 价格偏离 EMA 距离
        trend_distance_atr = row["trend_distance_atr"]

        # ATR 未极端扩张
        atr_not_extreme = (
            cfg["max_atr_expansion"] <= 0.0
            or row["atr"] <= atr_avg * cfg["max_atr_expansion"]
        )

        # ADX 未衰减
        adx_not_fading = (
            cfg["max_trend_adx_drop"] <= 0.0
            or row["adx"] >= df.iloc[idx - 2]["adx"] - cfg["max_trend_adx_drop"]
        )

        # 趋势质量（空头/多头）
        trend_quality_down = (
            not cfg["use_advanced_filters"]
            or (
                row["efficiency"] >= cfg["min_trend_efficiency_ratio"]
                and row["choppiness"] <= cfg["max_trend_choppiness"]
                and ema_gap_atr >= cfg["min_trend_ema_gap_atr"]
                and di_gap >= cfg["min_trend_di_gap"]
                and (cfg["max_trend_distance_atr"] <= 0.0 or trend_distance_atr <= cfg["max_trend_distance_atr"])
                and adx_not_fading
                and atr_not_extreme
            )
        )

        trend_quality_up = (
            not cfg["use_advanced_filters"]
            or (
                row["efficiency"] >= cfg["min_trend_efficiency_ratio"] + cfg["long_trend_efficiency_offset"]
                and row["choppiness"] <= cfg["max_trend_choppiness"]
                and ema_gap_atr >= cfg["min_trend_ema_gap_atr"]
                and di_gap >= cfg["min_trend_di_gap"] + cfg["long_trend_di_gap_offset"]
                and row["adx"] >= cfg["trend_adx_threshold"] + cfg["long_trend_adx_offset"]
                and (cfg["max_trend_distance_atr"] <= 0.0 or trend_distance_atr <= cfg["max_trend_distance_atr"])
                and adx_not_fading
                and atr_not_extreme
            )
        )

        # 高级区间过滤
        advanced_range_ok = (
            not cfg["use_advanced_filters"]
            or (
                row["choppiness"] >= cfg["min_choppiness"]
                and row["efficiency"] <= cfg["max_efficiency_ratio"]
                and atr_not_extreme
            )
        )

        # 趋势上涨（多头）
        if (
            row["adx"] >= cfg["trend_adx_threshold"]
            and atr_active
            and trend_quality_up
            and ema_up
            and close_above_mid
            and di_bullish
        ):
            return Regime.TREND_UP

        # 趋势下跌（空头）
        if (
            row["adx"] >= cfg["trend_adx_threshold"]
            and atr_active
            and trend_quality_down
            and ema_down
            and close_below_mid
            and di_bearish
        ):
            return Regime.TREND_DOWN

        # 震荡区间
        if (
            row["adx"] <= cfg["range_adx_threshold"]
            and ema_gap_atr <= cfg["range_ema_gap_atr"]
            and advanced_range_ok
            and self._has_usable_range(df, idx, atr_avg)
        ):
            return Regime.RANGE

        return Regime.UNKNOWN

    def _has_usable_range(self, df: pd.DataFrame, idx: int, atr_value: float) -> bool:
        """判断是否存在可用的震荡区间。"""
        cfg = self.cfg
        range_lookback = max(12, cfg["range_lookback_bars"])
        if idx < range_lookback + 2:
            return False

        start = max(2, idx - range_lookback + 1)
        range_high = highest_high(df, start, range_lookback)
        range_low = lowest_low(df, start, range_lookback)
        range_width_atr = (range_high - range_low) / max(atr_value, 0.001)

        return cfg["range_min_width_atr"] <= range_width_atr <= cfg["range_max_width_atr"]

    # ——— 趋势入场信号（Intrabar 精确入场，使用 M5 数据） ———

    def generate_trend_signal(
        self, df: pd.DataFrame, idx: int, regime: Regime
    ) -> tuple[Signal, float, float, str]:
        """基于 Intrabar 逻辑生成趋势信号。

        如果有 M5 数据，使用 M5 K线检测精确入场（对应 EA 的 BuildIntrabarTrendSignal）。
        否则回退到 M15 信号K线。

        Returns:
            (Signal, entry_price, sl, tp, reason)
        """
        if regime not in (Regime.TREND_UP, Regime.TREND_DOWN):
            return Signal.NONE, 0.0, 0.0, 0.0, ""

        cfg = self.cfg
        row = df.iloc[idx]
        atr_val = row["atr"]
        if atr_val <= 0:
            return Signal.NONE, 0.0, 0.0, 0.0, ""

        if row["adx"] < cfg["intrabar_trend_adx_threshold"]:
            return Signal.NONE, 0.0, 0.0, 0.0, ""

        # 使用 M5 数据做精确入场
        if self.df_m5 is not None:
            return self._intrabar_entry_m5(df, idx, regime, atr_val)

        # 回退：M15-only 简化入场
        return self._intrabar_entry_single_tf(df, idx, regime, atr_val)

    def _intrabar_entry_m5(
        self, df: pd.DataFrame, idx: int, regime: Regime, atr_val: float
    ) -> tuple[Signal, float, float, str]:
        """使用 M5 K线数据做 Intrabar 精确入场（对应 EA BuildIntrabarTrendSignal）。"""
        cfg = self.cfg
        signal_bar_time = df.index[idx]

        # 取 M5 数据中 <= 当前 M15 bar 时间 的最近 N 根 K线
        m5_before = self.df_m5[self.df_m5.index <= signal_bar_time]
        if len(m5_before) < 4:
            return Signal.NONE, 0.0, 0.0, 0.0, ""

        lookback = max(2, cfg["intrabar_lookback_bars"])
        bars_needed = lookback + 4
        if len(m5_before) < bars_needed:
            return Signal.NONE, 0.0, 0.0, 0.0, ""

        # 取最近的 M5 bars（最新的一根是刚完成的 M5 bar）
        m5_window = m5_before.iloc[-bars_needed:]

        bar = m5_window.iloc[-1]  # 最新 M5 bar
        bar_range = max(bar["high"] - bar["low"], 0.001)
        bar_body = abs(bar["close"] - bar["open"])
        body_ok = bar_body / bar_range >= cfg["min_entry_body_ratio"]
        bar_not_extreme = cfg["max_entry_bar_atr"] <= 0.0 or bar_range <= atr_val * cfg["max_entry_bar_atr"]

        # 近期高低点
        recent_high = m5_window["high"].iloc[-lookback-1:-1].max()
        recent_low = m5_window["low"].iloc[-lookback-1:-1].min()
        recent_move_ok = (
            cfg["max_intrabar_move_atr"] <= 0.0
            or (recent_high - recent_low) <= atr_val * cfg["max_intrabar_move_atr"]
        )

        buffer = atr_val * cfg["trend_breakout_buffer_atr"]
        pullback_min = atr_val * cfg["trend_pullback_min_atr"]
        had_pullback = recent_high - recent_low >= pullback_min

        if regime == Regime.TREND_UP:
            candle_ok = self._is_candle_confirm_df(m5_window, atr_val, True)
            breaks_high = bar["close"] >= recent_high + buffer
            bullish_bar = bar["close"] > bar["open"]
            close_strong = (bar["close"] - bar["low"]) / bar_range >= cfg["min_entry_close_position"]
            rsi_room = cfg["trend_buy_max_rsi"] <= 0.0 or df.iloc[idx]["rsi"] < cfg["trend_buy_max_rsi"]

            if (had_pullback and recent_move_ok and candle_ok and breaks_high
                and bullish_bar and close_strong and body_ok and bar_not_extreme and rsi_room):
                entry = bar["close"]
                sl, tp = self._calc_trend_sl_tp(df, idx, Signal.BUY, entry, atr_val)
                return Signal.BUY, entry, sl, tp, "趋势买入 v7: M5 K线确认回调突破"

            return Signal.NONE, 0.0, 0.0, 0.0, ""

        elif regime == Regime.TREND_DOWN:
            candle_ok = self._is_candle_confirm_df(m5_window, atr_val, False)
            breaks_low = bar["close"] <= recent_low - buffer
            bearish_bar = bar["close"] < bar["open"]
            close_weak = (bar["high"] - bar["close"]) / bar_range >= cfg["min_entry_close_position"]
            rsi_room = cfg["trend_sell_min_rsi"] <= 0.0 or df.iloc[idx]["rsi"] > cfg["trend_sell_min_rsi"]

            if (had_pullback and recent_move_ok and candle_ok and breaks_low
                and bearish_bar and close_weak and body_ok and bar_not_extreme and rsi_room):
                entry = bar["close"]
                sl, tp = self._calc_trend_sl_tp(df, idx, Signal.SELL, entry, atr_val)
                return Signal.SELL, entry, sl, tp, "趋势卖出 v7: M5 K线确认回调跌破"

            return Signal.NONE, 0.0, 0.0, 0.0, ""

        return Signal.NONE, 0.0, 0.0, 0.0, ""

    def _intrabar_entry_single_tf(
        self, df: pd.DataFrame, idx: int, regime: Regime, atr_val: float
    ) -> tuple[Signal, float, float, str]:
        """M15-only 简化入场（无 M5 数据时回退）。"""
        cfg = self.cfg
        row = df.iloc[idx]
        lookback = max(2, cfg["intrabar_lookback_bars"])
        if idx < lookback + 4:
            return Signal.NONE, 0.0, 0.0, 0.0, ""

        start_idx = max(2, idx - lookback + 1)
        recent_high = highest_high(df, start_idx, lookback)
        recent_low = lowest_low(df, start_idx, lookback)

        bar_range = max(row["high"] - row["low"], 0.001)
        bar_body = abs(row["close"] - row["open"])
        body_ok = bar_body / bar_range >= cfg["min_entry_body_ratio"]
        bar_not_extreme = cfg["max_entry_bar_atr"] <= 0.0 or bar_range <= atr_val * cfg["max_entry_bar_atr"]

        buffer = atr_val * cfg["trend_breakout_buffer_atr"]
        pullback_min = atr_val * cfg["trend_pullback_min_atr"]
        had_pullback = recent_high - recent_low >= pullback_min
        recent_move_ok = (
            cfg["max_intrabar_move_atr"] <= 0.0
            or (recent_high - recent_low) <= atr_val * cfg["max_intrabar_move_atr"]
        )

        if regime == Regime.TREND_UP:
            candle_ok = self._is_candle_confirm(df, idx, True, atr_val)
            breaks_high = row["close"] >= recent_high + buffer
            bullish_bar = row["close"] > row["open"]
            close_strong = (row["close"] - row["low"]) / bar_range >= cfg["min_entry_close_position"]
            rsi_room = cfg["trend_buy_max_rsi"] <= 0.0 or row["rsi"] < cfg["trend_buy_max_rsi"]
            if (had_pullback and recent_move_ok and candle_ok and breaks_high
                and bullish_bar and close_strong and body_ok and bar_not_extreme and rsi_room):
                sl, tp = self._calc_trend_sl_tp(df, idx, Signal.BUY, row["close"], atr_val)
                return Signal.BUY, row["close"], sl, tp, "趋势买入: K线确认回调突破"

        elif regime == Regime.TREND_DOWN:
            candle_ok = self._is_candle_confirm(df, idx, False, atr_val)
            breaks_low = row["close"] <= recent_low - buffer
            bearish_bar = row["close"] < row["open"]
            close_weak = (row["high"] - row["close"]) / bar_range >= cfg["min_entry_close_position"]
            rsi_room = cfg["trend_sell_min_rsi"] <= 0.0 or row["rsi"] > cfg["trend_sell_min_rsi"]
            if (had_pullback and recent_move_ok and candle_ok and breaks_low
                and bearish_bar and close_weak and body_ok and bar_not_extreme and rsi_room):
                sl, tp = self._calc_trend_sl_tp(df, idx, Signal.SELL, row["close"], atr_val)
                return Signal.SELL, row["close"], sl, tp, "趋势卖出: K线确认回调跌破"

        return Signal.NONE, 0.0, 0.0, 0.0, ""

    # ——— 区间反转入场信号 ———

    def generate_range_signal(
        self, df: pd.DataFrame, idx: int
    ) -> tuple[Signal, float, float, str]:
        """基于区间反转逻辑生成入场信号。

        对应 EA 的 BuildStrategySnapshot() 中 REGIME_RANGE 分支。

        Returns:
            (Signal, entry_price, sl, tp, reason)
        """
        cfg = self.cfg
        if idx < 12:
            return Signal.NONE, 0.0, 0.0, 0.0, ""

        row = df.iloc[idx]
        atr_val = row["atr"]
        if atr_val <= 0:
            return Signal.NONE, 0.0, 0.0, 0.0, ""

        range_lookback = max(12, cfg["range_lookback_bars"])
        if idx < range_lookback + 2:
            return Signal.NONE, 0.0, 0.0, 0.0, ""

        start = max(2, idx - range_lookback + 1)
        range_high = highest_high(df, start, range_lookback)
        range_low = lowest_low(df, start, range_lookback)

        edge_buffer = atr_val * cfg["range_edge_buffer_atr"]
        close_back = atr_val * cfg["range_close_back_inside_atr"]
        touch_buffer = atr_val * cfg["range_touch_buffer_atr"]
        false_break_buffer = atr_val * cfg["range_false_break_buffer_atr"]

        lower_touches = count_lower_boundary_touches(df, start, range_lookback, range_low, touch_buffer)
        upper_touches = count_upper_boundary_touches(df, start, range_lookback, range_high, touch_buffer)
        range_structure_ok = (
            lower_touches >= cfg["min_range_boundary_touches"]
            and upper_touches >= cfg["min_range_boundary_touches"]
        )

        if not range_structure_ok:
            return Signal.NONE, 0.0, 0.0, 0.0, ""

        near_lower = (
            row["low"] <= range_low + edge_buffer
            and row["close"] > range_low + close_back
            and row["close"] <= row["bb_mid"]
        )
        near_upper = (
            row["high"] >= range_high - edge_buffer
            and row["close"] < range_high - close_back
            and row["close"] >= row["bb_mid"]
        )

        # 假突破过滤
        buy_false_break = (
            not cfg["require_range_false_break"]
            or (row["low"] <= range_low - false_break_buffer and row["close"] > range_low + close_back)
        )
        sell_false_break = (
            not cfg["require_range_false_break"]
            or (row["high"] >= range_high + false_break_buffer and row["close"] < range_high - close_back)
        )

        # RSI 转向
        prev_row = df.iloc[idx - 1]
        rsi_turn_up = row["rsi"] <= cfg["rsi_oversold"] + 8.0 and row["rsi"] > prev_row["rsi"]
        rsi_turn_down = row["rsi"] >= cfg["rsi_overbought"] - 8.0 and row["rsi"] < prev_row["rsi"]

        # K线形态
        bullish_reject = is_bullish_rejection(row)
        bearish_reject = is_bearish_rejection(row)

        entry = row["close"]

        if near_lower and buy_false_break and rsi_turn_up and bullish_reject:
            sl, tp = self._calc_range_sl_tp(df, idx, Signal.BUY, entry, atr_val)
            return Signal.BUY, entry, sl, tp, "区间买入 v3: 支撑位假突破反转"

        if near_upper and sell_false_break and rsi_turn_down and bearish_reject:
            sl, tp = self._calc_range_sl_tp(df, idx, Signal.SELL, entry, atr_val)
            return Signal.SELL, entry, sl, tp, "区间卖出 v3: 阻力位假突破反转"

        return Signal.NONE, 0.0, 0.0, 0.0, ""

    # ——— 信号K线趋势入场（EA BuildStrategySnapshot 的 trend 分支） ———

    def _generate_signal_bar_entry(
        self, df: pd.DataFrame, idx: int, regime: Regime
    ) -> tuple[Signal, float, float, float, str]:
        """信号K线趋势入场 — 对应 EA 的 BuildStrategySnapshot() 中 TREND_UP/TREND_DOWN 分支。

        这是 EA 启用 use_signal_bar_trend_entry 时的主要入场路径，条件更简单：
        - 回撤到 EMA 附近
        - 重新延续趋势（close 突破前高/前低）
        - RSI 未极端
        - K线波幅不太大
        """
        cfg = self.cfg
        if idx < 3:
            return Signal.NONE, 0.0, 0.0, 0.0, ""

        row = df.iloc[idx]
        prev = df.iloc[idx - 1]
        prev2 = df.iloc[idx - 2]
        atr_val = row["atr"]
        if atr_val <= 0:
            return Signal.NONE, 0.0, 0.0, 0.0, ""

        if regime == Regime.TREND_UP:
            # 回撤到 EMA 快线附近
            pullback = (
                row["low"] <= row["ema_fast"] + atr_val * 0.25
                or prev["low"] <= prev["ema_fast"] + atr_val * 0.25
                or row["low"] <= row["bb_mid"] + atr_val * 0.20
            )

            # K线波幅过滤
            bar_range = row["high"] - row["low"]
            signal_bar_ok = (
                cfg["max_signal_bar_atr"] <= 0.0
                or bar_range <= atr_val * cfg["max_signal_bar_atr"]
            )

            # 恢复上涨（close 高于 EMA 快线 且 close 突破前高）
            resumed = row["close"] > row["ema_fast"] and row["close"] > prev["high"]
            rsi_room = cfg["trend_buy_max_rsi"] <= 0.0 or row["rsi"] < cfg["trend_buy_max_rsi"]

            if pullback and resumed and rsi_room and signal_bar_ok:
                sl, tp = self._calc_trend_sl_tp(df, idx, Signal.BUY, row["close"], atr_val)
                return Signal.BUY, row["close"], sl, tp, "趋势买入: 强势回撤延续"

        elif regime == Regime.TREND_DOWN:
            # 反弹到 EMA 快线附近
            pullback = (
                row["high"] >= row["ema_fast"] - atr_val * 0.25
                or prev["high"] >= prev["ema_fast"] - atr_val * 0.25
                or row["high"] >= row["bb_mid"] - atr_val * 0.20
            )

            bar_range = row["high"] - row["low"]
            signal_bar_ok = (
                cfg["max_signal_bar_atr"] <= 0.0
                or bar_range <= atr_val * cfg["max_signal_bar_atr"]
            )

            # 恢复下跌
            resumed = row["close"] < row["ema_fast"] and row["close"] < prev["low"]
            rsi_room = cfg["trend_sell_min_rsi"] <= 0.0 or row["rsi"] > cfg["trend_sell_min_rsi"]

            if pullback and resumed and rsi_room and signal_bar_ok:
                sl, tp = self._calc_trend_sl_tp(df, idx, Signal.SELL, row["close"], atr_val)
                return Signal.SELL, row["close"], sl, tp, "趋势卖出: 强势反弹延续"

        return Signal.NONE, 0.0, 0.0, 0.0, ""

    # ——— 止损止盈计算 ———

    def _calc_trend_sl_tp(
        self, df: pd.DataFrame, idx: int, signal: Signal, entry: float, atr_val: float
    ) -> tuple[float, float]:
        """计算趋势模式的止损和止盈。"""
        cfg = self.cfg
        if idx < 10:
            return 0.0, 0.0

        start = max(1, idx - 9)
        if signal == Signal.BUY:
            swing_sl = lowest_low(df, start, 10) - atr_val * 0.20
            atr_sl = entry - atr_val * cfg["trend_atr_stop_multiplier"]
            sl = min(swing_sl, atr_sl) if cfg["use_wider_trend_stop"] else max(swing_sl, atr_sl)
            rr = self._effective_trend_rr(True)
            tp = entry + (entry - sl) * rr
        else:
            swing_sl = highest_high(df, start, 10) + atr_val * 0.20
            atr_sl = entry + atr_val * cfg["trend_atr_stop_multiplier"]
            sl = max(swing_sl, atr_sl) if cfg["use_wider_trend_stop"] else min(swing_sl, atr_sl)
            rr = self._effective_trend_rr(False)
            tp = entry - (sl - entry) * rr

        return sl, tp

    def _calc_range_sl_tp(
        self, df: pd.DataFrame, idx: int, signal: Signal, entry: float, atr_val: float
    ) -> tuple[float, float]:
        """计算区间模式的止损和止盈。"""
        cfg = self.cfg
        row = df.iloc[idx]

        if signal == Signal.BUY:
            sl = entry - atr_val * cfg["range_atr_stop_multiplier"]
            rr_tp = entry + (entry - sl) * cfg["range_reward_risk"]
            tp = min(row["bb_mid"], rr_tp)
        else:
            sl = entry + atr_val * cfg["range_atr_stop_multiplier"]
            rr_tp = entry - (sl - entry) * cfg["range_reward_risk"]
            tp = max(row["bb_mid"], rr_tp)

        return sl, tp

    # ——— K线形态确认 ———

    def _is_candle_confirm(
        self, df: pd.DataFrame, idx: int, is_buy: bool, atr_val: float
    ) -> bool:
        """K线过滤 — 对应 EA 的 IsTrendCandleConfirmationOk()。"""
        cfg = self.cfg
        if not cfg["use_candle_trend_filter"]:
            return True
        if idx < 6 or atr_val <= 0:
            return True

        row = df.iloc[idx]
        bar_range = max(row["high"] - row["low"], 0.001)
        body = abs(row["close"] - row["open"])

        # 实体大小
        if body < atr_val * cfg["candle_min_body_atr"]:
            return False

        # 反向影线比例
        if is_buy:
            opposite_wick = row["high"] - max(row["open"], row["close"])
        else:
            opposite_wick = min(row["open"], row["close"]) - row["low"]

        if opposite_wick / bar_range > cfg["candle_max_opposite_wick_ratio"]:
            return False

        # 动量收盘
        lookback = max(1, cfg["candle_momentum_lookback"])
        required = max(0, min(lookback, cfg["candle_min_momentum_closes"]))
        if required <= 0:
            return True

        momentum_closes = 0
        for i in range(1, min(lookback + 1, idx)):
            prev_close = df["close"].iloc[idx - i]
            prev2_close = df["close"].iloc[idx - i - 1]
            if is_buy and prev_close > prev2_close:
                momentum_closes += 1
            elif not is_buy and prev_close < prev2_close:
                momentum_closes += 1

        return momentum_closes >= required

    def _is_candle_confirm_df(
        self, df_window: pd.DataFrame, atr_val: float, is_buy: bool
    ) -> bool:
        """K线确认 — DataFrame 窗口版本（用于 M5 数据）。"""
        cfg = self.cfg
        if not cfg["use_candle_trend_filter"]:
            return True
        if len(df_window) < 6 or atr_val <= 0:
            return True

        row = df_window.iloc[-1]
        bar_range = max(row["high"] - row["low"], 0.001)
        body = abs(row["close"] - row["open"])

        if body < atr_val * cfg["candle_min_body_atr"]:
            return False

        if is_buy:
            opposite_wick = row["high"] - max(row["open"], row["close"])
        else:
            opposite_wick = min(row["open"], row["close"]) - row["low"]

        if opposite_wick / bar_range > cfg["candle_max_opposite_wick_ratio"]:
            return False

        lookback = max(1, cfg["candle_momentum_lookback"])
        required = max(0, min(lookback, cfg["candle_min_momentum_closes"]))
        if required <= 0:
            return True

        momentum_closes = 0
        for i in range(1, min(lookback + 1, len(df_window) - 1)):
            prev_close = df_window["close"].iloc[-i]
            prev2_close = df_window["close"].iloc[-i - 1]
            if is_buy and prev_close > prev2_close:
                momentum_closes += 1
            elif not is_buy and prev_close < prev2_close:
                momentum_closes += 1

        return momentum_closes >= required

    # ——— 盈亏比 ———

    def _effective_trend_rr(self, is_buy: bool) -> float:
        """获取有效趋势盈亏比（支持长短分离）。"""
        cfg = self.cfg
        if is_buy and cfg["long_trend_reward_risk"] > 0:
            return cfg["long_trend_reward_risk"]
        if not is_buy and cfg["short_trend_reward_risk"] > 0:
            return cfg["short_trend_reward_risk"]
        return cfg["trend_reward_risk"]

    # ——— 主入口：一站式信号生成 ———

    def evaluate(
        self, df: pd.DataFrame, idx: int
    ) -> StrategySnapshot:
        """一站式策略评估入口。

        1. 计算 ATR 均值
        2. 识别行情状态
        3. 根据状态生成入场信号
        4. 计算止损止盈
        """
        snap = StrategySnapshot()

        if idx < 40:
            snap.reason = "等待足够指标数据"
            return snap

        # ATR 均值（与 EA AverageAtr 对齐）
        atr_vals = df["atr"].iloc[idx - 23 : idx + 1] if idx >= 23 else df["atr"].iloc[: idx + 1]
        atr_avg = atr_vals.mean() if len(atr_vals) > 0 else 0.0
        if atr_avg <= 0:
            snap.reason = "ATR 数据不足"
            return snap

        row = df.iloc[idx]

        # 填充快照基本数据
        snap.adx = row["adx"]
        snap.rsi = row["rsi"]
        snap.atr = row["atr"]
        snap.choppiness = row["choppiness"]
        snap.efficiency = row["efficiency"]
        snap.ema_fast = row["ema_fast"]
        snap.ema_slow = row["ema_slow"]
        snap.bands_mid = row["bb_mid"]
        snap.bands_upper = row["bb_upper"]
        snap.bands_lower = row["bb_lower"]
        snap.vwap_deviation_atr = row["vwap_deviation_atr"]
        snap.higher_trend = 1 if row.get("supertrend", 0) > 0 else (-1 if row.get("supertrend", 0) < 0 else 0)

        # 1. 识别行情状态
        snap.regime = self.detect_regime(df, idx, atr_avg)

        signal = Signal.NONE
        entry = sl = tp = 0.0
        reason = ""

        # 1.5 长周期 EMA200 趋势过滤 — 只做顺大势方向
        if self.cfg.get("use_ema200_trend_filter", False):
            ema200 = row.get("ema_200", 0.0)
            if ema200 > 0:
                ema200_up = row["ema_200"] > df["ema_200"].iloc[max(0, idx - 20)]
                price_above_ema = row["close"] > ema200
                price_below_ema = row["close"] < ema200
                if snap.regime == Regime.TREND_DOWN and (ema200_up or price_above_ema):
                    snap.reason = "趋势下跌被EMA200大势过滤"
                    snap.regime = Regime.UNKNOWN
                elif snap.regime == Regime.TREND_UP and (not ema200_up or price_below_ema):
                    snap.reason = "趋势上涨被EMA200大势过滤"
                    snap.regime = Regime.UNKNOWN

        # 2. 根据行情状态生成信号
        if snap.regime == Regime.TREND_UP or snap.regime == Regime.TREND_DOWN:
            # 信号K线路径（对应 EA BuildStrategySnapshot 的 trend 分支）
            if self.cfg.get("use_signal_bar_trend_entry", True):
                signal, entry, sl, tp, reason = self._generate_signal_bar_entry(df, idx, snap.regime)
            # Intrabar 路径（对应 EA BuildIntrabarTrendSignal）
            if signal == Signal.NONE and self.cfg.get("use_intrabar_trend_entry", True):
                signal, entry, sl, tp, reason = self.generate_trend_signal(df, idx, snap.regime)

        elif snap.regime == Regime.RANGE:
            signal, entry, sl, tp, reason = self.generate_range_signal(df, idx)

        else:
            if not reason:
                row = df.iloc[idx]
                if row["adx"] > self.cfg["range_adx_threshold"] and row["adx"] < self.cfg["trend_adx_threshold"]:
                    reason = "不交易: ADX 处于中性区域"
                else:
                    reason = "不交易: 行情状态不明确"

        # 3. 交易方向过滤
        trade_dir = self.cfg.get("trade_direction", "both")
        if trade_dir == "long_only" and signal == Signal.SELL:
            signal = Signal.NONE
            reason = "只做多过滤卖信号"
        elif trade_dir == "short_only" and signal == Signal.BUY:
            signal = Signal.NONE
            reason = "只做空过滤买信号"

        snap.signal = signal
        snap.entry = entry
        snap.sl = sl
        snap.tp = tp
        snap.reason = reason

        return snap


def generate_signals(df: pd.DataFrame, config: dict, df_m5: pd.DataFrame | None = None) -> pd.DataFrame:
    """对整个 DataFrame 逐行运行策略信号引擎，返回信号 DataFrame。

    Args:
        df: 已计算好所有指标的 DataFrame
        config: strategy 配置字典

    Returns:
        DataFrame，包含 regime, signal, entry, sl, tp, reason 列
    """
    engine = SignalEngine(config, df_m5=df_m5)

    regimes = []
    signals = []
    entries = []
    sls = []
    tps = []
    reasons = []

    for idx in range(len(df)):
        snap = engine.evaluate(df, idx)
        regimes.append(snap.regime.value)
        signals.append(snap.signal.value)
        entries.append(snap.entry)
        sls.append(snap.sl)
        tps.append(snap.tp)
        reasons.append(snap.reason)

    return pd.DataFrame(
        {
            "regime": regimes,
            "signal": signals,
            "entry": entries,
            "sl": sls,
            "tp": tps,
            "reason": reasons,
        },
        index=df.index,
    )
