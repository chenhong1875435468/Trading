"""
回测引擎 — 模拟交易执行、持仓管理、盈亏计算。
基于信号 DataFrame 和 OHLC 数据，逐K线推进模拟交易。
"""

import numpy as np
import pandas as pd
from dataclasses import dataclass, field
from typing import Optional

from .signals import Signal


@dataclass
class Trade:
    """单笔交易记录。"""
    entry_time: pd.Timestamp
    exit_time: Optional[pd.Timestamp] = None
    direction: int = 0           # 1=多, -1=空
    entry_price: float = 0.0
    exit_price: float = 0.0
    initial_sl: float = 0.0      # 开仓时的原始止损
    sl: float = 0.0              # 当前止损（可能被移动止损调整）
    tp: float = 0.0
    lots: float = 0.01
    profit: float = 0.0
    profit_r: float = 0.0        # 盈亏以R为单位（基于原始止损）
    exit_reason: str = ""        # tp / sl / close / trail / be


@dataclass
class BacktestResult:
    """回测结果。"""
    trades: list[Trade] = field(default_factory=list)
    equity_curve: pd.Series | None = None
    initial_capital: float = 100.0
    final_equity: float = 100.0
    net_profit: float = 0.0
    profit_factor: float = 0.0
    total_trades: int = 0
    winning_trades: int = 0
    losing_trades: int = 0
    win_rate: float = 0.0
    avg_win: float = 0.0
    avg_loss: float = 0.0
    max_equity_dd: float = 0.0
    max_equity_dd_pct: float = 0.0
    sharpe_ratio: float = 0.0
    avg_r: float = 0.0
    expectancy: float = 0.0


class BacktestEngine:
    """逐K线回测引擎。

    Args:
        df_ohlc: OHLC DataFrame（含所有指标列）
        df_signals: 信号 DataFrame（由 signals.generate_signals() 生成）
        config: strategy 配置字典
        initial_capital: 初始资金
        fixed_lot: 固定手数
    """

    def __init__(
        self,
        df_ohlc: pd.DataFrame,
        df_signals: pd.DataFrame,
        config: dict,
        initial_capital: float = 100.0,
        fixed_lot: float = 0.01,
    ):
        self.df = df_ohlc
        self.signals = df_signals
        self.cfg = config
        self.initial_capital = initial_capital
        self.fixed_lot = fixed_lot

    def run(self) -> BacktestResult:
        """执行回测。"""
        trades: list[Trade] = []
        equity = self.initial_capital
        equity_curve = [self.initial_capital]
        dates = [self.df.index[0]]

        # 活跃持仓
        active_trade: Trade | None = None
        # 风控状态
        daily_trades = 0
        daily_pnl = 0.0
        current_date = None
        consecutive_losses = 0
        last_trade_bar = -999
        last_loss_bar = -999

        for i in range(len(self.df)):
            bar_time = self.df.index[i]
            bar_date = bar_time.date() if hasattr(bar_time, "date") else bar_time

            # 每日重置
            if bar_date != current_date:
                current_date = bar_date
                daily_trades = 0
                daily_pnl = 0.0

            high, low, close = (
                self.df["high"].iloc[i],
                self.df["low"].iloc[i],
                self.df["close"].iloc[i],
            )
            atr_val = self.df["atr"].iloc[i] if "atr" in self.df.columns else 0.0

            # ——— 持仓管理 ———
            if active_trade is not None:
                trade = active_trade
                reason = ""
                exit_price = 0.0

                if trade.direction == 1:  # 多头
                    if low <= trade.sl:
                        exit_price = trade.sl
                        reason = "sl"
                    elif high >= trade.tp:
                        exit_price = trade.tp
                        reason = "tp"
                else:  # 空头
                    if high >= trade.sl:
                        exit_price = trade.sl
                        reason = "sl"
                    elif low <= trade.tp:
                        exit_price = trade.tp
                        reason = "tp"

                # 出场管理：保本止损 + ATR 移动止损
                if reason == "" and atr_val > 0:
                    exit_price, reason = self._manage_exit(
                        trade, bar_time, i, close, atr_val, high, low
                    )

                if reason != "":
                    trade.exit_time = bar_time
                    trade.exit_price = exit_price
                    trade.exit_reason = reason

                    # 计算盈亏
                    pip_value = 1.0  # XAUUSD 1点=1美元 per 0.01 lot近似
                    if trade.direction == 1:
                        trade.profit = (exit_price - trade.entry_price) * trade.lots * 100.0
                    else:
                        trade.profit = (trade.entry_price - exit_price) * trade.lots * 100.0

                    # R倍数（基于原始止损）
                    risk_distance = abs(trade.entry_price - trade.initial_sl)
                    if risk_distance > 0:
                        trade.profit_r = (
                            (exit_price - trade.entry_price) / risk_distance
                            if trade.direction == 1
                            else (trade.entry_price - exit_price) / risk_distance
                        )

                    equity += trade.profit
                    daily_pnl += trade.profit

                    if trade.profit > 0:
                        consecutive_losses = 0
                    else:
                        consecutive_losses += 1
                        last_loss_bar = i

                    trades.append(trade)
                    active_trade = None
                    daily_trades += 1

            # ——— 入场信号 ———
            if active_trade is None and i < len(self.signals):
                sig_row = self.signals.iloc[i]
                sig_val = sig_row["signal"]

                if sig_val in (Signal.BUY.value, Signal.SELL.value):
                    # 简单风控检查
                    if not self._check_risk_limits(
                        i, daily_trades, daily_pnl, consecutive_losses,
                        last_trade_bar, last_loss_bar
                    ):
                        equity_curve.append(equity)
                        dates.append(bar_time)
                        continue

                    entry = sig_row.get("entry", 0.0)
                    if entry <= 0:
                        entry = close
                    sl = sig_row["sl"]
                    tp = sig_row["tp"]

                    if sl <= 0 or tp <= 0:
                        equity_curve.append(equity)
                        dates.append(bar_time)
                        continue

                    direction = 1 if sig_val == Signal.BUY.value else -1
                    active_trade = Trade(
                        entry_time=bar_time,
                        direction=direction,
                        entry_price=entry,
                        initial_sl=sl,
                        sl=sl,
                        tp=tp,
                        lots=self.fixed_lot,
                    )
                    last_trade_bar = i

            equity_curve.append(equity)
            dates.append(bar_time)

        # 强制平仓
        if active_trade is not None:
            last_close = self.df["close"].iloc[-1]
            active_trade.exit_time = self.df.index[-1]
            active_trade.exit_price = last_close
            active_trade.exit_reason = "close"
            if active_trade.direction == 1:
                active_trade.profit = (last_close - active_trade.entry_price) * active_trade.lots * 100.0
            else:
                active_trade.profit = (active_trade.entry_price - last_close) * active_trade.lots * 100.0
            trades.append(active_trade)
            equity += active_trade.profit

        return self._build_result(trades, equity_curve, dates)

    def _manage_exit(
        self, trade: Trade, bar_time, bar_idx: int, close: float, atr_val: float,
        high: float, low: float
    ) -> tuple[float, str]:
        """管理出场：保本止损和ATR移动止损。"""
        cfg = self.cfg

        if trade.entry_price <= 0:
            return 0.0, ""

        risk_dist = abs(trade.entry_price - trade.sl)
        if risk_dist <= 0:
            return 0.0, ""

        if trade.direction == 1:
            profit_dist = close - trade.entry_price
        else:
            profit_dist = trade.entry_price - close

        r_multiple = profit_dist / risk_dist

        # 最大亏损R平仓
        if cfg["max_loss_close_r"] > 0 and r_multiple <= -cfg["max_loss_close_r"]:
            return close, "maxloss"

        if r_multiple <= 0:
            return 0.0, ""

        # 保本止损
        if cfg["use_breakeven_stop"] and r_multiple >= cfg["breakeven_trigger_r"]:
            be_sl = trade.entry_price + (cfg["breakeven_buffer_points"] * 0.01 if trade.direction == 1
                                         else -cfg["breakeven_buffer_points"] * 0.01)
            if trade.direction == 1 and be_sl > trade.sl:
                trade.sl = be_sl
            elif trade.direction == -1 and be_sl < trade.sl:
                trade.sl = be_sl

        # ATR 移动止损
        if cfg["use_atr_trailing_stop"] and r_multiple >= cfg["atr_trail_trigger_r"] and atr_val > 0:
            trail_dist = atr_val * cfg["atr_trail_multiplier"]
            if trade.direction == 1:
                trail_sl = close - trail_dist
                if trail_sl > trade.sl:
                    trade.sl = trail_sl
            else:
                trail_sl = close + trail_dist
                if trail_sl < trade.sl:
                    trade.sl = trail_sl

        # Do not test the newly modified stop against the same completed bar.
        # EA modifies stops on the current tick/new entry bar; the bar's prior
        # high/low is already in the past. The new stop can only be hit later.
        return 0.0, ""

    def _check_risk_limits(
        self, bar_idx: int, daily_trades: int, daily_pnl: float,
        consecutive_losses: int, last_trade_bar: int, last_loss_bar: int,
    ) -> bool:
        """简单的风控检查（与 EA 对齐）。"""
        cfg = self.cfg

        # 每日交易数限制
        if cfg["max_trades_per_day"] > 0 and daily_trades >= cfg["max_trades_per_day"]:
            return False

        # 每日亏损限制
        if cfg["max_daily_loss_money"] > 0 and daily_pnl <= -cfg["max_daily_loss_money"]:
            return False

        # 连续亏损限制
        if cfg["max_consecutive_losses"] > 0 and consecutive_losses >= cfg["max_consecutive_losses"]:
            return False

        # K线间隔冷却
        if cfg["min_bars_between_trades"] > 0 and last_trade_bar >= 0:
            if bar_idx - last_trade_bar < cfg["min_bars_between_trades"]:
                return False

        # 连续亏损冷却
        if cfg["loss_cooldown_threshold"] > 0 and cfg["loss_cooldown_bars"] > 0:
            if consecutive_losses >= cfg["loss_cooldown_threshold"] and last_loss_bar >= 0:
                if bar_idx - last_loss_bar < cfg["loss_cooldown_bars"]:
                    return False

        return True

    def _build_result(
        self, trades: list[Trade], equity_curve: list[float], dates: list
    ) -> BacktestResult:
        """构建回测结果对象，计算各项指标。"""
        result = BacktestResult()
        result.trades = trades
        result.initial_capital = self.initial_capital

        eq_series = pd.Series(equity_curve, index=dates[:len(equity_curve)])
        result.equity_curve = eq_series

        result.total_trades = len(trades)
        if result.total_trades == 0:
            result.final_equity = self.initial_capital
            return result

        result.final_equity = equity_curve[-1]
        result.net_profit = result.final_equity - self.initial_capital

        wins = [t for t in trades if t.profit > 0]
        losses = [t for t in trades if t.profit < 0]
        result.winning_trades = len(wins)
        result.losing_trades = len(losses)
        result.win_rate = result.winning_trades / result.total_trades * 100.0

        result.avg_win = np.mean([t.profit for t in wins]) if wins else 0.0
        result.avg_loss = np.mean([abs(t.profit) for t in losses]) if losses else 0.0

        gross_profit = sum(t.profit for t in wins)
        gross_loss = sum(abs(t.profit) for t in losses)
        result.profit_factor = gross_profit / gross_loss if gross_loss > 0 else float("inf")

        # 回撤
        running_max = eq_series.cummax()
        drawdown = eq_series - running_max
        result.max_equity_dd = drawdown.min()
        dd_pct = drawdown / running_max.replace(0, 1) * 100.0
        result.max_equity_dd_pct = dd_pct.min()

        # R倍数
        r_values = [t.profit_r for t in trades if abs(t.entry_price - t.sl) > 0]
        result.avg_r = np.mean(r_values) if r_values else 0.0

        # 期望值
        result.expectancy = result.win_rate / 100.0 * result.avg_win - (
            1.0 - result.win_rate / 100.0
        ) * result.avg_loss

        # 夏普比率（年化）
        returns = eq_series.pct_change().dropna()
        if len(returns) > 1 and returns.std() > 0:
            result.sharpe_ratio = returns.mean() / returns.std() * np.sqrt(252)

        return result


def backtest(df_ohlc: pd.DataFrame, df_signals: pd.DataFrame, config: dict,
             initial_capital: float = 100.0, fixed_lot: float = 0.01) -> BacktestResult:
    """便捷回测函数。"""
    engine = BacktestEngine(df_ohlc, df_signals, config, initial_capital, fixed_lot)
    return engine.run()


def trades_to_dataframe(trades: list[Trade]) -> pd.DataFrame:
    """将交易列表转为 DataFrame 便于分析。"""
    if not trades:
        return pd.DataFrame()
    return pd.DataFrame([
        {
            "entry_time": t.entry_time,
            "exit_time": t.exit_time,
            "direction": "BUY" if t.direction == 1 else "SELL",
            "entry": t.entry_price,
            "exit": t.exit_price,
            "sl": t.sl,
            "tp": t.tp,
            "profit": round(t.profit, 2),
            "profit_r": round(t.profit_r, 2),
            "reason": t.exit_reason,
        }
        for t in trades
    ])
