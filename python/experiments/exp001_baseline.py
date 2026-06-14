"""
实验 001：基线回测 — 加载数据、计算指标、生成信号、运行回测。
验证 Python 回测引擎的基本功能是否正常。
"""

import sys
from pathlib import Path

# 添加父目录到 path
sys.path.insert(0, str(Path(__file__).parent.parent))

from core.config import load_config
from core.data_loader import load_xauusd_m15
from core.indicators import compute_all
from core.signals import generate_signals
from core.backtest_engine import backtest, trades_to_dataframe


def main():
    print("=" * 60)
    print("实验 001: XAUUSD 基线回测")
    print("=" * 60)

    # 1. 加载配置
    print("\n[1/5] 加载配置...")
    cfg = load_config()

    # 2. 加载数据
    print("[2/5] 加载数据...")
    df = load_xauusd_m15()
    print(f"  M15 数据: {df.index.min()} → {df.index.max()}, {len(df)} 行")
    print(f"  价格范围: {df['close'].min():.2f} – {df['close'].max():.2f}")

    # 尝试加载 M5 数据用于 Intrabar 入场
    from core.data_loader import load_mt5_csv, clean_data
    m5_path = Path(__file__).parent.parent / "data" / "raw" / "XAUUSD_M5.csv"
    df_m5 = None
    if m5_path.exists():
        df_m5 = load_mt5_csv(str(m5_path))
        df_m5 = clean_data(df_m5)
        print(f"  M5  数据: {df_m5.index.min()} → {df_m5.index.max()}, {len(df_m5)} 行")

    # 3. 计算指标
    print("[3/5] 计算技术指标...")
    df = compute_all(df, cfg["strategy"])
    print(f"  指标列: {[c for c in df.columns if c not in ('open','high','low','close','tickvol','vol','spread')]}")

    # 丢弃指标计算期间的 NaN 行
    df = df.dropna()
    print(f"  有效行数（去NaN后）: {len(df)}")

    # 4. 生成信号
    print("[4/5] 生成交易信号...")
    signals_df = generate_signals(df, cfg["strategy"], df_m5=df_m5)

    # 统计信号分布
    signal_counts = signals_df["signal"].value_counts()
    regime_counts = signals_df["regime"].value_counts()
    print(f"  行情分布: TREND_UP={regime_counts.get(1,0)}, TREND_DOWN={regime_counts.get(2,0)}, "
          f"RANGE={regime_counts.get(3,0)}, UNKNOWN={regime_counts.get(0,0)}")
    print(f"  信号数: BUY={signal_counts.get(1,0)}, SELL={signal_counts.get(2,0)}, NONE={signal_counts.get(0,0)}")

    # 5. 回测
    print("[5/5] 运行回测...")
    result = backtest(
        df, signals_df, cfg["strategy"],
        initial_capital=cfg["backtest"]["initial_capital"],
        fixed_lot=cfg["backtest"]["fixed_lot"],
    )

    # 输出结果
    print("\n" + "=" * 60)
    print("回测结果")
    print("=" * 60)
    print(f"  初始资金:       {result.initial_capital:>10.2f}")
    print(f"  最终权益:       {result.final_equity:>10.2f}")
    print(f"  净利润:         {result.net_profit:>10.2f}")
    print(f"  总交易数:       {result.total_trades:>10}")
    print(f"  盈利交易:       {result.winning_trades:>10}")
    print(f"  亏损交易:       {result.losing_trades:>10}")
    print(f"  胜率:           {result.win_rate:>9.1f}%")
    print(f"  平均盈利:       {result.avg_win:>10.2f}")
    print(f"  平均亏损:       {result.avg_loss:>10.2f}")
    print(f"  盈亏比 (PF):    {result.profit_factor:>10.2f}")
    print(f"  平均R:          {result.avg_r:>10.2f}")
    print(f"  期望值:         {result.expectancy:>10.2f}")
    print(f"  最大回撤:       {result.max_equity_dd:>10.2f}")
    print(f"  最大回撤率:     {result.max_equity_dd_pct:>9.1f}%")
    print(f"  夏普比率:       {result.sharpe_ratio:>10.2f}")

    # 交易明细
    trades_df = trades_to_dataframe(result.trades)
    if len(trades_df) > 0:
        print(f"\n  最近 5 笔交易:")
        print(trades_df.tail(5).to_string(index=False))

    # 保存交易明细
    output_dir = Path(__file__).parent.parent / "reports" / "experiments"
    output_dir.mkdir(parents=True, exist_ok=True)
    trades_df.to_csv(output_dir / "exp001_trades.csv", index=False)
    print(f"\n交易明细已保存至: {output_dir / 'exp001_trades.csv'}")

    return result


if __name__ == "__main__":
    main()
