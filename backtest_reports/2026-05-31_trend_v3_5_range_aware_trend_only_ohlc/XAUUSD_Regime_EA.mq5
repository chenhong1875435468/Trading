#property strict
#property version   "1.500"
#property description "XAUUSD regime-based EA: trend-following + range-reversal with risk controls and chart panel."

enum ENUM_LOT_MODE
{
   LOT_FIXED = 0,
   LOT_RISK_PERCENT = 1
};

enum ENUM_TRADE_DIRECTION
{
   DIRECTION_BOTH = 0,
   DIRECTION_LONG_ONLY = 1,
   DIRECTION_SHORT_ONLY = 2
};

enum ENUM_STRATEGY_MODE
{
   STRATEGY_AUTO = 0,
   STRATEGY_TREND_ONLY = 1,
   STRATEGY_RANGE_ONLY = 2
};

enum ENUM_RANGE_TARGET_MODE
{
   RANGE_TARGET_NEAREST = 0,
   RANGE_TARGET_FARTHEST = 1
};

enum ENUM_RANGE_STOP_MODE
{
   RANGE_STOP_STRUCTURE = 0,
   RANGE_STOP_ATR = 1
};

enum ENUM_MARKET_REGIME
{
   REGIME_UNKNOWN = 0,
   REGIME_TREND_UP = 1,
   REGIME_TREND_DOWN = 2,
   REGIME_RANGE = 3
};

enum ENUM_TRADE_SIGNAL
{
   SIGNAL_NONE = 0,
   SIGNAL_BUY = 1,
   SIGNAL_SELL = 2
};

input string               InpTradeSymbol              = "";
input ENUM_TIMEFRAMES      InpSignalTimeframe          = PERIOD_M15;
input ENUM_TIMEFRAMES      InpHigherTimeframe          = PERIOD_M30;
input long                 InpMagicNumber              = 26052201;
input ENUM_TRADE_DIRECTION InpTradeDirection           = DIRECTION_BOTH;
input ENUM_STRATEGY_MODE   InpStrategyMode             = STRATEGY_TREND_ONLY;
input bool                 InpStartAutoTrading         = true;

input ENUM_LOT_MODE        InpLotMode                  = LOT_FIXED;
input double               InpFixedLot                 = 0.01;
input double               InpRiskPercent              = 0.50;
input double               InpMaxActualRiskPercent     = 0.00;
input bool                 InpAllowMinLotIfRiskTooLow  = true;

input int                  InpFastEmaPeriod            = 21;
input int                  InpSlowEmaPeriod            = 55;
input int                  InpAdxPeriod                = 14;
input double               InpTrendAdxThreshold        = 24.0;
input double               InpRangeAdxThreshold        = 22.0;
input int                  InpRsiPeriod                = 14;
input double               InpRsiOverbought            = 68.0;
input double               InpRsiOversold              = 32.0;
input int                  InpAtrPeriod                = 14;
input double               InpMinAtrFactor             = 0.50;
input int                  InpBandsPeriod              = 20;
input double               InpBandsDeviation           = 2.0;
input int                  InpRangeLookbackBars        = 36;
input double               InpRangeMinWidthAtr         = 2.0;
input double               InpRangeMaxWidthAtr         = 8.0;
input double               InpRangeEmaGapAtr           = 1.60;
input bool                 InpUseAdvancedFilters       = true;
input int                  InpChoppinessPeriod         = 14;
input double               InpMinChoppiness            = 48.0;
input int                  InpEfficiencyPeriod         = 14;
input double               InpMaxEfficiencyRatio       = 0.40;
input double               InpMinTrendEfficiencyRatio  = 0.34;
input double               InpMaxTrendChoppiness       = 55.0;
input double               InpMinTrendEmaGapAtr        = 0.25;
input double               InpMinTrendDiGap            = 6.0;
input double               InpMaxTrendDistanceAtr      = 2.20;
input double               InpLongTrendAdxOffset       = 3.0;
input double               InpLongTrendEfficiencyOffset = 0.06;
input double               InpLongTrendDiGapOffset     = 2.0;
input bool                 InpUseVwapFilter            = true;
input double               InpMinVwapDeviationAtr      = 0.10;
input bool                 InpUseLiquiditySweep        = true;
input int                  InpSweepLookbackBars        = 24;
input double               InpSweepBufferAtr           = 0.04;
input double               InpRangeEdgeBufferAtr       = 0.25;
input double               InpRangeCloseBackInsideAtr  = 0.05;
input bool                 InpUseSupertrendFilter      = false;
input int                  InpSupertrendPeriod         = 10;
input double               InpSupertrendMultiplier     = 3.0;
input double               InpMaxAtrExpansion          = 3.20;
input bool                 InpUseSignalBarTrendEntry   = true;
input bool                 InpUseIntrabarTrendEntry    = true;
input bool                 InpSynchronizeTrendEntryToBar = true;
input ENUM_TIMEFRAMES      InpEntryTimeframe           = PERIOD_M5;
input double               InpIntrabarTrendAdxThreshold = 28.0;
input int                  InpIntrabarLookbackBars     = 6;
input double               InpTrendBreakoutBufferAtr   = 0.05;
input double               InpTrendPullbackMinAtr      = 0.25;
input double               InpMinEntryBodyRatio        = 0.45;
input double               InpMinEntryClosePosition    = 0.65;
input double               InpMaxEntryBarAtr           = 0.80;
input double               InpMaxSignalBarAtr          = 1.20;
input double               InpMaxIntrabarMoveAtr       = 1.60;

input bool                 InpUseWiderTrendStop        = false;
input double               InpTrendAtrStopMultiplier   = 1.35;
input double               InpRangeAtrStopBuffer       = 0.25;
input double               InpTrendRewardRisk          = 1.80;
input double               InpRangeRewardRisk          = 1.05;
input ENUM_RANGE_TARGET_MODE InpRangeTargetMode        = RANGE_TARGET_FARTHEST;
input ENUM_RANGE_STOP_MODE InpRangeStopMode            = RANGE_STOP_STRUCTURE;
input double               InpRangeAtrStopMultiplier   = 0.55;
input int                  InpMinStopPoints            = 80;
input int                  InpMaxStopPoints            = 2500;
input double               InpMinTrendTradeR           = 1.40;
input double               InpMinRangeTradeR           = 0.90;

input int                  InpMaxSpreadPoints          = 350;
input int                  InpMaxSlippagePoints        = 30;
input int                  InpMaxOpenPositions         = 1;
input int                  InpMaxTradesPerDay          = 0;
input double               InpMaxDailyLossPercent      = 0.0;
input double               InpMaxDailyLossMoney        = 0.0;
input int                  InpMaxConsecutiveLosses     = 0;
input int                  InpMinBarsBetweenTrades     = 2;
input int                  InpLossCooldownThreshold    = 2;
input int                  InpLossCooldownBars         = 4;
input bool                 InpUseBreakevenStop         = true;
input double               InpBreakevenTriggerR        = 0.80;
input int                  InpBreakevenBufferPoints    = 30;
input bool                 InpUseAtrTrailingStop       = true;
input double               InpAtrTrailTriggerR         = 1.25;
input double               InpAtrTrailMultiplier       = 1.40;
input int                  InpMinManagedStopStepPoints = 250;
input bool                 InpManageStopsOnEntryBarOnly = true;
input bool                 InpUseTradeHours            = false;
input int                  InpTradeStartHour           = 7;
input int                  InpTradeEndHour             = 23;

input bool                 InpShowPanel                = true;
input bool                 InpDisablePanelInTester     = true;
input int                  InpPanelX                   = 12;
input int                  InpPanelY                   = 24;
input bool                 InpDebugSignalLog           = false;

struct StrategySnapshot
{
   ENUM_MARKET_REGIME regime;
   ENUM_TRADE_SIGNAL  signal;
   double             entry;
   double             sl;
   double             tp;
   double             adx;
   double             rsi;
   double             atr;
   double             choppiness;
   double             efficiency;
   double             vwap_deviation_atr;
   double             spread_points;
   int                higher_trend;
   string             reason;
};

string   g_symbol = "";
int      g_digits = 0;
double   g_point = 0.0;
bool     g_auto_enabled = true;
string   g_profile_name = "Standard";
double   g_profile_risk_multiplier = 1.0;
datetime g_last_signal_bar_time = 0;
datetime g_last_trade_bar_time = 0;
datetime g_last_intrabar_signal_time = 0;
datetime g_last_entry_bar_time = 0;
datetime g_last_history_check = 0;
datetime g_last_loss_deal_time = 0;
string   g_last_reason = "Waiting";
string   g_last_trade_result = "No trade yet";
double   g_daily_profit = 0.0;
int      g_daily_trades = 0;
int      g_consecutive_losses = 0;
int      g_diag_bars = 0;
int      g_diag_trend_up = 0;
int      g_diag_trend_down = 0;
int      g_diag_range = 0;
int      g_diag_unclear = 0;
int      g_diag_buy_signals = 0;
int      g_diag_sell_signals = 0;
int      g_diag_blocked = 0;
int      g_diag_order_attempts = 0;
int      g_diag_order_success = 0;
int      g_diag_block_auto_paused = 0;
int      g_diag_block_trade_disabled = 0;
int      g_diag_block_symbol_disabled = 0;
int      g_diag_block_hours = 0;
int      g_diag_block_spread = 0;
int      g_diag_block_direction = 0;
int      g_diag_block_open_positions = 0;
int      g_diag_block_daily_trade_limit = 0;
int      g_diag_block_daily_loss = 0;
int      g_diag_block_consecutive_loss = 0;
int      g_diag_block_cooldown = 0;
int      g_diag_block_stop_too_large = 0;
int      g_diag_block_stop_too_small = 0;
int      g_diag_block_reward_risk = 0;
int      g_diag_block_lot = 0;
int      g_diag_block_actual_risk = 0;
int      g_diag_block_unknown = 0;

int g_fast_ema_handle = INVALID_HANDLE;
int g_slow_ema_handle = INVALID_HANDLE;
int g_fast_ema_higher_handle = INVALID_HANDLE;
int g_slow_ema_higher_handle = INVALID_HANDLE;
int g_adx_handle = INVALID_HANDLE;
int g_atr_handle = INVALID_HANDLE;
int g_rsi_handle = INVALID_HANDLE;
int g_bands_handle = INVALID_HANDLE;

const string PANEL_PREFIX = "XAU_REGIME_PANEL_";

int OnInit()
{
   g_symbol = (InpTradeSymbol == "" ? _Symbol : InpTradeSymbol);
   g_digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
   g_point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   g_auto_enabled = InpStartAutoTrading;

   if(!SymbolSelect(g_symbol, true))
   {
      Print("Cannot select symbol: ", g_symbol);
      return INIT_FAILED;
   }

   if(!CreateIndicatorHandles())
      return INIT_FAILED;

   RefreshRiskStats();

   if(IsPanelEnabled())
   {
      CreatePanel();
      EventSetTimer(1);
   }

   Print("EA initialized for ", g_symbol, " on ", EnumToString(InpSignalTimeframe));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   PrintDiagnostics();
   EventKillTimer();
   ReleaseIndicatorHandles();
   DeletePanel();
}

void OnTimer()
{
   if(!IsPanelEnabled())
      return;

   RefreshRiskStats();
   UpdatePanel();
}

void OnTick()
{
   if(_Symbol != g_symbol && InpTradeSymbol == "")
      return;

   RefreshSymbolMeta();

   bool is_new_entry_bar = IsNewEntryBar();
   ManageOpenPositions(is_new_entry_bar);
   bool is_new_signal_bar = IsNewSignalBar();
   if(!is_new_signal_bar && (!InpUseIntrabarTrendEntry || !is_new_entry_bar))
      return;

   StrategySnapshot snapshot;
   ResetSnapshot(snapshot);

   if(!BuildStrategySnapshot(snapshot))
   {
      g_last_reason = "Waiting for enough indicator data";
      UpdatePanel();
      return;
   }

   g_last_reason = snapshot.reason;

   if(!is_new_signal_bar)
   {
      snapshot.signal = SIGNAL_NONE;
      snapshot.reason = "Waiting for intrabar trend trigger";
      g_last_reason = snapshot.reason;
   }

   bool intrabar_signal = false;
   if(InpUseIntrabarTrendEntry && InpStrategyMode != STRATEGY_RANGE_ONLY &&
      (snapshot.signal == SIGNAL_NONE || snapshot.regime == REGIME_TREND_UP || snapshot.regime == REGIME_TREND_DOWN))
   {
      intrabar_signal = BuildIntrabarTrendSignal(snapshot, is_new_entry_bar);
      g_last_reason = snapshot.reason;
   }

   if(is_new_signal_bar || snapshot.signal != SIGNAL_NONE)
      TrackDiagnostics(snapshot);

   if(snapshot.signal == SIGNAL_NONE)
   {
      if(is_new_signal_bar)
         UpdatePanel();
      return;
   }

   string block_reason = "";
   if(!CanOpenTrade(snapshot, block_reason))
   {
      g_diag_blocked++;
      TrackBlockedTrade(block_reason);
      if(InpDebugSignalLog)
         Print("Signal blocked: ", block_reason, " | ", snapshot.reason);
      g_last_trade_result = "Blocked: " + block_reason;
      g_last_reason = block_reason;
      UpdatePanel();
      return;
   }

   double lots = CalculateOrderLots(snapshot.entry, snapshot.sl, block_reason);
   if(lots <= 0.0)
   {
      g_diag_blocked++;
      TrackBlockedTrade(block_reason);
      if(InpDebugSignalLog)
         Print("Signal blocked: ", block_reason, " | ", snapshot.reason);
      g_last_trade_result = "Blocked: " + block_reason;
      g_last_reason = block_reason;
      UpdatePanel();
      return;
   }

   g_diag_order_attempts++;
   if(SendMarketOrder(snapshot.signal, lots, snapshot.sl, snapshot.tp, snapshot.reason))
   {
      g_diag_order_success++;
      g_last_trade_bar_time = iTime(g_symbol, InpSignalTimeframe, 0);
      if(intrabar_signal)
         g_last_intrabar_signal_time = iTime(g_symbol, InpEntryTimeframe, 0);
   }

   RefreshRiskStats();
   UpdatePanel();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK)
      return;

   if(sparam == PANEL_PREFIX + "BTN_AUTO")
   {
      g_auto_enabled = !g_auto_enabled;
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   }
   else if(sparam == PANEL_PREFIX + "BTN_CLOSE")
   {
      CloseAllManagedPositions();
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   }
   else if(sparam == PANEL_PREFIX + "BTN_SAFE")
   {
      g_profile_name = "Conservative";
      g_profile_risk_multiplier = 0.5;
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   }
   else if(sparam == PANEL_PREFIX + "BTN_STANDARD")
   {
      g_profile_name = "Standard";
      g_profile_risk_multiplier = 1.0;
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   }
   else if(sparam == PANEL_PREFIX + "BTN_AGGRESSIVE")
   {
      g_profile_name = "Aggressive";
      g_profile_risk_multiplier = 1.8;
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   }

   UpdatePanel();
   ChartRedraw(0);
}

bool CreateIndicatorHandles()
{
   g_fast_ema_handle = iMA(g_symbol, InpSignalTimeframe, InpFastEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_slow_ema_handle = iMA(g_symbol, InpSignalTimeframe, InpSlowEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_fast_ema_higher_handle = iMA(g_symbol, InpHigherTimeframe, InpFastEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_slow_ema_higher_handle = iMA(g_symbol, InpHigherTimeframe, InpSlowEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_adx_handle = iADX(g_symbol, InpSignalTimeframe, InpAdxPeriod);
   g_atr_handle = iATR(g_symbol, InpSignalTimeframe, InpAtrPeriod);
   g_rsi_handle = iRSI(g_symbol, InpSignalTimeframe, InpRsiPeriod, PRICE_CLOSE);
   g_bands_handle = iBands(g_symbol, InpSignalTimeframe, InpBandsPeriod, 0, InpBandsDeviation, PRICE_CLOSE);

   if(g_fast_ema_handle == INVALID_HANDLE || g_slow_ema_handle == INVALID_HANDLE ||
      g_fast_ema_higher_handle == INVALID_HANDLE || g_slow_ema_higher_handle == INVALID_HANDLE ||
      g_adx_handle == INVALID_HANDLE || g_atr_handle == INVALID_HANDLE ||
      g_rsi_handle == INVALID_HANDLE || g_bands_handle == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles. Error: ", GetLastError());
      return false;
   }

   return true;
}

void ReleaseIndicatorHandles()
{
   if(g_fast_ema_handle != INVALID_HANDLE) IndicatorRelease(g_fast_ema_handle);
   if(g_slow_ema_handle != INVALID_HANDLE) IndicatorRelease(g_slow_ema_handle);
   if(g_fast_ema_higher_handle != INVALID_HANDLE) IndicatorRelease(g_fast_ema_higher_handle);
   if(g_slow_ema_higher_handle != INVALID_HANDLE) IndicatorRelease(g_slow_ema_higher_handle);
   if(g_adx_handle != INVALID_HANDLE) IndicatorRelease(g_adx_handle);
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_rsi_handle != INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
   if(g_bands_handle != INVALID_HANDLE) IndicatorRelease(g_bands_handle);
}

void ResetSnapshot(StrategySnapshot &snapshot)
{
   snapshot.regime = REGIME_UNKNOWN;
   snapshot.signal = SIGNAL_NONE;
   snapshot.entry = 0.0;
   snapshot.sl = 0.0;
   snapshot.tp = 0.0;
   snapshot.adx = 0.0;
   snapshot.rsi = 0.0;
   snapshot.atr = 0.0;
   snapshot.choppiness = 0.0;
   snapshot.efficiency = 0.0;
   snapshot.vwap_deviation_atr = 0.0;
   snapshot.spread_points = CurrentSpreadPoints();
   snapshot.higher_trend = 0;
   snapshot.reason = "No clear setup";
}

bool BuildStrategySnapshot(StrategySnapshot &snapshot)
{
   ResetSnapshot(snapshot);

   int bars_needed = InpRangeLookbackBars + 20;
   bars_needed = MathMax(bars_needed, InpChoppinessPeriod + 20);
   bars_needed = MathMax(bars_needed, InpEfficiencyPeriod + 20);
   bars_needed = MathMax(bars_needed, InpSweepLookbackBars + 20);
   if(bars_needed < 90)
      bars_needed = 90;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(g_symbol, InpSignalTimeframe, 0, bars_needed, rates) < bars_needed)
      return false;

   double ema_fast[], ema_slow[], ema_fast_higher[], ema_slow_higher[];
   double adx[], plus_di[], minus_di[], atr[], rsi[], bands_mid[], bands_upper[], bands_lower[];
   ArraySetAsSeries(ema_fast, true);
   ArraySetAsSeries(ema_slow, true);
   ArraySetAsSeries(ema_fast_higher, true);
   ArraySetAsSeries(ema_slow_higher, true);
   ArraySetAsSeries(adx, true);
   ArraySetAsSeries(plus_di, true);
   ArraySetAsSeries(minus_di, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(bands_mid, true);
   ArraySetAsSeries(bands_upper, true);
   ArraySetAsSeries(bands_lower, true);

   if(CopyBuffer(g_fast_ema_handle, 0, 0, 8, ema_fast) < 8) return false;
   if(CopyBuffer(g_slow_ema_handle, 0, 0, 8, ema_slow) < 8) return false;
   if(CopyBuffer(g_fast_ema_higher_handle, 0, 0, 8, ema_fast_higher) < 8) return false;
   if(CopyBuffer(g_slow_ema_higher_handle, 0, 0, 8, ema_slow_higher) < 8) return false;
   if(CopyBuffer(g_adx_handle, 0, 0, 8, adx) < 8) return false;
   if(CopyBuffer(g_adx_handle, 1, 0, 8, plus_di) < 8) return false;
   if(CopyBuffer(g_adx_handle, 2, 0, 8, minus_di) < 8) return false;
   if(CopyBuffer(g_atr_handle, 0, 0, 40, atr) < 40) return false;
   if(CopyBuffer(g_rsi_handle, 0, 0, 8, rsi) < 8) return false;
   if(CopyBuffer(g_bands_handle, 0, 0, 8, bands_mid) < 8) return false;
   if(CopyBuffer(g_bands_handle, 1, 0, 8, bands_upper) < 8) return false;
   if(CopyBuffer(g_bands_handle, 2, 0, 8, bands_lower) < 8) return false;

   double atr_average = AverageAtr(atr, 2, 24);
   if(atr_average <= 0.0)
      return false;

   snapshot.adx = adx[1];
   snapshot.rsi = rsi[1];
   snapshot.atr = atr[1];
   snapshot.spread_points = CurrentSpreadPoints();
   snapshot.choppiness = CalculateChoppiness(rates, MathMax(2, InpChoppinessPeriod));
   snapshot.efficiency = CalculateEfficiencyRatio(rates, MathMax(2, InpEfficiencyPeriod));
   double session_vwap = CalculateSessionVwap(rates);
   if(session_vwap > 0.0 && atr[1] > 0.0)
      snapshot.vwap_deviation_atr = (rates[1].close - session_vwap) / atr[1];
   snapshot.higher_trend = CalculateSupertrendDirection();

   bool ema_up = ema_fast[1] > ema_slow[1] && ema_fast[1] > ema_fast[3] && ema_slow[1] >= ema_slow[3];
   bool ema_down = ema_fast[1] < ema_slow[1] && ema_fast[1] < ema_fast[3] && ema_slow[1] <= ema_slow[3];
   bool higher_up = ema_fast_higher[1] > ema_slow_higher[1] &&
                    ema_fast_higher[1] > ema_fast_higher[3] &&
                    ema_slow_higher[1] >= ema_slow_higher[3];
   bool higher_down = ema_fast_higher[1] < ema_slow_higher[1] &&
                      ema_fast_higher[1] < ema_fast_higher[3] &&
                      ema_slow_higher[1] <= ema_slow_higher[3];
   bool atr_active = atr[1] >= atr_average * InpMinAtrFactor;
   bool close_above_mid = rates[1].close > bands_mid[1];
   bool close_below_mid = rates[1].close < bands_mid[1];
   double di_gap = MathAbs(plus_di[1] - minus_di[1]);
   bool di_bullish = plus_di[1] > minus_di[1] &&
                     plus_di[1] >= plus_di[2] &&
                     plus_di[1] - minus_di[1] >= InpMinTrendDiGap;
   bool di_bearish = minus_di[1] > plus_di[1] &&
                     minus_di[1] >= minus_di[2] &&
                     minus_di[1] - plus_di[1] >= InpMinTrendDiGap;
   double ema_gap_atr = MathAbs(ema_fast[1] - ema_slow[1]) / MathMax(atr[1], g_point);
   double trend_distance_atr = MathAbs(rates[1].close - ema_fast[1]) / MathMax(atr[1], g_point);
   bool atr_not_extreme = InpMaxAtrExpansion <= 0.0 || atr[1] <= atr_average * InpMaxAtrExpansion;
   bool trend_quality_down_ok = !InpUseAdvancedFilters ||
                                (snapshot.efficiency >= InpMinTrendEfficiencyRatio &&
                                 snapshot.choppiness <= InpMaxTrendChoppiness &&
                                 ema_gap_atr >= InpMinTrendEmaGapAtr &&
                                 di_gap >= InpMinTrendDiGap &&
                                 (InpMaxTrendDistanceAtr <= 0.0 || trend_distance_atr <= InpMaxTrendDistanceAtr) &&
                                 atr_not_extreme);
   bool trend_quality_up_ok = !InpUseAdvancedFilters ||
                              (snapshot.efficiency >= InpMinTrendEfficiencyRatio + InpLongTrendEfficiencyOffset &&
                               snapshot.choppiness <= InpMaxTrendChoppiness &&
                               ema_gap_atr >= InpMinTrendEmaGapAtr &&
                               di_gap >= InpMinTrendDiGap + InpLongTrendDiGapOffset &&
                               adx[1] >= InpTrendAdxThreshold + InpLongTrendAdxOffset &&
                               (InpMaxTrendDistanceAtr <= 0.0 || trend_distance_atr <= InpMaxTrendDistanceAtr) &&
                               atr_not_extreme);
   bool advanced_range_ok = !InpUseAdvancedFilters ||
                            (snapshot.choppiness >= InpMinChoppiness &&
                             snapshot.efficiency <= InpMaxEfficiencyRatio &&
                             atr_not_extreme);

   if(adx[1] >= InpTrendAdxThreshold && atr_active && trend_quality_up_ok &&
      ema_up && higher_up && close_above_mid && di_bullish)
      snapshot.regime = REGIME_TREND_UP;
   else if(adx[1] >= InpTrendAdxThreshold && atr_active && trend_quality_down_ok &&
           ema_down && higher_down && close_below_mid && di_bearish)
      snapshot.regime = REGIME_TREND_DOWN;
   else if(adx[1] <= InpRangeAdxThreshold && ema_gap_atr <= InpRangeEmaGapAtr &&
           HasUsableRange(rates, atr[1]) && advanced_range_ok)
      snapshot.regime = REGIME_RANGE;
   else
      snapshot.regime = REGIME_UNKNOWN;

   ENUM_TRADE_SIGNAL signal = SIGNAL_NONE;
   string reason = "";

   if(snapshot.regime == REGIME_TREND_UP)
   {
      if(InpStrategyMode == STRATEGY_RANGE_ONLY)
      {
         reason = "Trend regime ignored by range-only mode";
      }
      else
      {
      bool pullback = rates[1].low <= ema_fast[1] + atr[1] * 0.25 ||
                      rates[2].low <= ema_fast[2] + atr[1] * 0.25 ||
                      rates[1].low <= bands_mid[1] + atr[1] * 0.20;
      bool signal_bar_ok = InpMaxSignalBarAtr <= 0.0 ||
                           (rates[1].high - rates[1].low) <= atr[1] * InpMaxSignalBarAtr;
      bool resumed = rates[1].close > ema_fast[1] && rates[1].close > rates[2].high;
      bool rsi_room = rsi[1] < 64.0;
      if(!InpUseSignalBarTrendEntry)
      {
         reason = "Trend up, waiting for entry-timeframe breakout";
      }
      else if(pullback && resumed && rsi_room && signal_bar_ok)
      {
         signal = SIGNAL_BUY;
         reason = "Trend buy: ADX strong, HTF up, pullback resumed";
      }
      else
      {
         reason = "Trend up, but no safe pullback entry";
      }
      }
   }
   else if(snapshot.regime == REGIME_TREND_DOWN)
   {
      if(InpStrategyMode == STRATEGY_RANGE_ONLY)
      {
         reason = "Trend regime ignored by range-only mode";
      }
      else
      {
      bool pullback = rates[1].high >= ema_fast[1] - atr[1] * 0.25 ||
                      rates[2].high >= ema_fast[2] - atr[1] * 0.25 ||
                      rates[1].high >= bands_mid[1] - atr[1] * 0.20;
      bool signal_bar_ok = InpMaxSignalBarAtr <= 0.0 ||
                           (rates[1].high - rates[1].low) <= atr[1] * InpMaxSignalBarAtr;
      bool resumed = rates[1].close < ema_fast[1] && rates[1].close < rates[2].low;
      bool rsi_room = rsi[1] > 36.0;
      if(!InpUseSignalBarTrendEntry)
      {
         reason = "Trend down, waiting for entry-timeframe breakdown";
      }
      else if(pullback && resumed && rsi_room && signal_bar_ok)
      {
         signal = SIGNAL_SELL;
         reason = "Trend sell: ADX strong, HTF down, pullback resumed";
      }
      else
      {
         reason = "Trend down, but no safe pullback entry";
      }
      }
   }
   else if(snapshot.regime == REGIME_RANGE)
   {
      if(InpStrategyMode == STRATEGY_TREND_ONLY)
      {
         reason = "Range regime ignored by trend-only mode";
      }
      else
      {
      int range_lookback = MathMax(12, InpRangeLookbackBars);
      double range_low = LowestLow(rates, 2, range_lookback);
      double range_high = HighestHigh(rates, 2, range_lookback);
      double edge_buffer = atr[1] * MathMax(0.0, InpRangeEdgeBufferAtr);
      double close_back = atr[1] * MathMax(0.0, InpRangeCloseBackInsideAtr);
      bool near_lower = rates[1].low <= range_low + edge_buffer &&
                        rates[1].close > range_low + close_back &&
                        rates[1].close <= bands_mid[1];
      bool near_upper = rates[1].high >= range_high - edge_buffer &&
                        rates[1].close < range_high - close_back &&
                        rates[1].close >= bands_mid[1];
      bool rsi_turn_up = rsi[1] <= InpRsiOversold + 8.0 && rsi[1] > rsi[2];
      bool rsi_turn_down = rsi[1] >= InpRsiOverbought - 8.0 && rsi[1] < rsi[2];
      bool bullish_reject = IsBullishRejection(rates[1]);
      bool bearish_reject = IsBearishRejection(rates[1]);
      bool buy_vwap_ok = !InpUseAdvancedFilters || !InpUseVwapFilter ||
                         snapshot.vwap_deviation_atr <= -InpMinVwapDeviationAtr;
      bool sell_vwap_ok = !InpUseAdvancedFilters || !InpUseVwapFilter ||
                          snapshot.vwap_deviation_atr >= InpMinVwapDeviationAtr;
      bool buy_sweep_ok = !InpUseAdvancedFilters || !InpUseLiquiditySweep ||
                          IsBullishLiquiditySweep(rates, atr[1]);
      bool sell_sweep_ok = !InpUseAdvancedFilters || !InpUseLiquiditySweep ||
                           IsBearishLiquiditySweep(rates, atr[1]);
      bool buy_higher_ok = !InpUseAdvancedFilters || !InpUseSupertrendFilter ||
                           snapshot.higher_trend >= 0;
      bool sell_higher_ok = !InpUseAdvancedFilters || !InpUseSupertrendFilter ||
                            snapshot.higher_trend <= 0;

      if(near_lower && rsi_turn_up && bullish_reject && buy_vwap_ok && buy_sweep_ok && buy_higher_ok)
      {
         signal = SIGNAL_BUY;
         reason = "Range buy v2: lower rejection with VWAP/RSI filters";
      }
      else if(near_upper && rsi_turn_down && bearish_reject && sell_vwap_ok && sell_sweep_ok && sell_higher_ok)
      {
         signal = SIGNAL_SELL;
         reason = "Range sell v2: upper rejection with VWAP/RSI filters";
      }
      else
      {
         reason = "Range regime, but advanced entry filters are not aligned";
      }
      }
   }
   else
   {
      if(adx[1] > InpRangeAdxThreshold && adx[1] < InpTrendAdxThreshold)
         reason = "No trade: ADX is in neutral zone";
      else
         reason = "No trade: market regime is unclear";
   }

   snapshot.signal = signal;
   snapshot.reason = reason;

   if(signal != SIGNAL_NONE)
      BuildTradePrices(snapshot, rates, atr[1], bands_mid[1], bands_upper[1], bands_lower[1]);

   return true;
}

bool BuildIntrabarTrendSignal(StrategySnapshot &snapshot, bool is_new_entry_bar)
{
   if(InpSynchronizeTrendEntryToBar && !is_new_entry_bar)
      return false;
   if(snapshot.regime != REGIME_TREND_UP && snapshot.regime != REGIME_TREND_DOWN)
      return false;
   if(snapshot.adx < InpIntrabarTrendAdxThreshold)
      return false;
   if(snapshot.atr <= 0.0)
      return false;

   MqlRates entry_rates[];
   ArraySetAsSeries(entry_rates, true);

   int lookback = MathMax(2, InpIntrabarLookbackBars);
   int bars_needed = lookback + 4;
   if(CopyRates(g_symbol, InpEntryTimeframe, 0, bars_needed, entry_rates) < bars_needed)
      return false;

   datetime entry_bar_time = entry_rates[0].time;
   if(entry_bar_time <= 0 || entry_bar_time == g_last_intrabar_signal_time)
      return false;

   double buffer = snapshot.atr * MathMax(0.0, InpTrendBreakoutBufferAtr);
   double pullback_min = snapshot.atr * MathMax(0.0, InpTrendPullbackMinAtr);
   double recent_high = HighestHigh(entry_rates, 2, lookback);
   double recent_low = LowestLow(entry_rates, 2, lookback);
   double bar_range = MathMax(entry_rates[1].high - entry_rates[1].low, g_point);
   double bar_body = MathAbs(entry_rates[1].close - entry_rates[1].open);
   double confirmation_close = entry_rates[1].close;
   bool body_ok = bar_body / bar_range >= MathMax(0.0, InpMinEntryBodyRatio);
   bool bar_not_extreme = InpMaxEntryBarAtr <= 0.0 || bar_range <= snapshot.atr * InpMaxEntryBarAtr;
   bool recent_move_ok = InpMaxIntrabarMoveAtr <= 0.0 ||
                         (recent_high - recent_low) <= snapshot.atr * InpMaxIntrabarMoveAtr;

   if(snapshot.regime == REGIME_TREND_UP)
   {
      bool had_pullback = recent_high - recent_low >= pullback_min;
      bool breaks_high = confirmation_close >= recent_high + buffer;
      bool bullish_bar = entry_rates[1].close > entry_rates[1].open;
      bool close_strong = (entry_rates[1].close - entry_rates[1].low) / bar_range >= InpMinEntryClosePosition;
      bool rsi_room = snapshot.rsi < 66.0;
      if(had_pullback && recent_move_ok && breaks_high && bullish_bar && close_strong && body_ok && bar_not_extreme && rsi_room)
      {
         snapshot.signal = SIGNAL_BUY;
         snapshot.reason = "Trend buy v3: closed M5 breakout in strong uptrend";
         BuildTradePricesFromMarket(snapshot);
         g_last_intrabar_signal_time = entry_bar_time;
         return true;
      }
   }
   else if(snapshot.regime == REGIME_TREND_DOWN)
   {
      bool had_pullback = recent_high - recent_low >= pullback_min;
      bool breaks_low = confirmation_close <= recent_low - buffer;
      bool bearish_bar = entry_rates[1].close < entry_rates[1].open;
      bool close_weak = (entry_rates[1].high - entry_rates[1].close) / bar_range >= InpMinEntryClosePosition;
      bool rsi_room = snapshot.rsi > 28.0;
      if(had_pullback && recent_move_ok && breaks_low && bearish_bar && close_weak && body_ok && bar_not_extreme && rsi_room)
      {
         snapshot.signal = SIGNAL_SELL;
         snapshot.reason = "Trend sell v3: closed M5 breakdown in strong downtrend";
         BuildTradePricesFromMarket(snapshot);
         g_last_intrabar_signal_time = entry_bar_time;
         return true;
      }
   }

   return false;
}

void BuildTradePricesFromMarket(StrategySnapshot &snapshot)
{
   MqlRates rates[];
   double bands_mid[], bands_upper[], bands_lower[];
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(bands_mid, true);
   ArraySetAsSeries(bands_upper, true);
   ArraySetAsSeries(bands_lower, true);

   if(CopyRates(g_symbol, InpSignalTimeframe, 0, 16, rates) < 16)
      return;
   if(CopyBuffer(g_bands_handle, 0, 0, 4, bands_mid) < 4)
      return;
   if(CopyBuffer(g_bands_handle, 1, 0, 4, bands_upper) < 4)
      return;
   if(CopyBuffer(g_bands_handle, 2, 0, 4, bands_lower) < 4)
      return;

   BuildTradePrices(snapshot, rates, snapshot.atr, bands_mid[1], bands_upper[1], bands_lower[1]);
}

void BuildTradePrices(StrategySnapshot &snapshot, MqlRates &rates[], double atr_value,
                      double band_mid, double band_upper, double band_lower)
{
   double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   bool is_buy = snapshot.signal == SIGNAL_BUY;
   snapshot.entry = is_buy ? ask : bid;

   if(snapshot.regime == REGIME_TREND_UP || snapshot.regime == REGIME_TREND_DOWN)
   {
      if(is_buy)
      {
         double swing_sl = LowestLow(rates, 1, 10) - atr_value * 0.20;
         double atr_sl = snapshot.entry - atr_value * InpTrendAtrStopMultiplier;
         snapshot.sl = InpUseWiderTrendStop ? MathMin(swing_sl, atr_sl)
                                            : MathMax(swing_sl, atr_sl);
         snapshot.tp = snapshot.entry + (snapshot.entry - snapshot.sl) * EffectiveTrendRewardRisk();
      }
      else
      {
         double swing_sl = HighestHigh(rates, 1, 10) + atr_value * 0.20;
         double atr_sl = snapshot.entry + atr_value * InpTrendAtrStopMultiplier;
         snapshot.sl = InpUseWiderTrendStop ? MathMax(swing_sl, atr_sl)
                                            : MathMin(swing_sl, atr_sl);
         snapshot.tp = snapshot.entry - (snapshot.sl - snapshot.entry) * EffectiveTrendRewardRisk();
      }
   }
   else if(snapshot.regime == REGIME_RANGE)
   {
      if(is_buy)
      {
         if(InpRangeStopMode == RANGE_STOP_ATR)
            snapshot.sl = snapshot.entry - atr_value * InpRangeAtrStopMultiplier;
         else
            snapshot.sl = MathMin(rates[1].low - atr_value * InpRangeAtrStopBuffer,
                                  band_lower - atr_value * 0.20);
         double rr_tp = snapshot.entry + (snapshot.entry - snapshot.sl) * InpRangeRewardRisk;
         snapshot.tp = (InpRangeTargetMode == RANGE_TARGET_NEAREST ? MathMin(band_mid, rr_tp)
                                                                    : MathMax(band_mid, rr_tp));
      }
      else
      {
         if(InpRangeStopMode == RANGE_STOP_ATR)
            snapshot.sl = snapshot.entry + atr_value * InpRangeAtrStopMultiplier;
         else
            snapshot.sl = MathMax(rates[1].high + atr_value * InpRangeAtrStopBuffer,
                                  band_upper + atr_value * 0.20);
         double rr_tp = snapshot.entry - (snapshot.sl - snapshot.entry) * InpRangeRewardRisk;
         snapshot.tp = (InpRangeTargetMode == RANGE_TARGET_NEAREST ? MathMax(band_mid, rr_tp)
                                                                    : MathMin(band_mid, rr_tp));
      }
   }

   NormalizeAndValidateStops(snapshot);
}

void NormalizeAndValidateStops(StrategySnapshot &snapshot)
{
   double min_stop = MathMax((double)InpMinStopPoints, (double)SymbolInfoInteger(g_symbol, SYMBOL_TRADE_STOPS_LEVEL) + 5.0) * g_point;
   bool is_buy = snapshot.signal == SIGNAL_BUY;

   if(is_buy)
   {
      if(snapshot.entry - snapshot.sl < min_stop)
         snapshot.sl = snapshot.entry - min_stop;
      if(snapshot.tp - snapshot.entry < min_stop)
         snapshot.tp = snapshot.entry + min_stop;
   }
   else if(snapshot.signal == SIGNAL_SELL)
   {
      if(snapshot.sl - snapshot.entry < min_stop)
         snapshot.sl = snapshot.entry + min_stop;
      if(snapshot.entry - snapshot.tp < min_stop)
         snapshot.tp = snapshot.entry - min_stop;
   }

   snapshot.entry = NormalizeDouble(snapshot.entry, g_digits);
   snapshot.sl = NormalizeDouble(snapshot.sl, g_digits);
   snapshot.tp = NormalizeDouble(snapshot.tp, g_digits);
}

bool CanOpenTrade(const StrategySnapshot &snapshot, string &reason)
{
   if(!g_auto_enabled)
   {
      reason = "Auto trading is paused";
      return false;
   }

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      reason = "Trading is disabled by terminal or account";
      return false;
   }

   if(SymbolInfoInteger(g_symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
   {
      reason = "Symbol trading mode is disabled";
      return false;
   }

   if(InpUseTradeHours && !IsWithinTradeHours())
   {
      reason = "Outside configured trade hours";
      return false;
   }

   if(CurrentSpreadPoints() > InpMaxSpreadPoints)
   {
      reason = "Spread is too high";
      return false;
   }

   if(snapshot.signal == SIGNAL_BUY && InpTradeDirection == DIRECTION_SHORT_ONLY)
   {
      reason = "Long trades are disabled";
      return false;
   }

   if(snapshot.signal == SIGNAL_SELL && InpTradeDirection == DIRECTION_LONG_ONLY)
   {
      reason = "Short trades are disabled";
      return false;
   }

   if(CountOpenPositions() >= InpMaxOpenPositions)
   {
      reason = "Maximum open positions reached";
      return false;
   }

   if(InpMaxTradesPerDay > 0 && g_daily_trades >= InpMaxTradesPerDay)
   {
      reason = "Daily trade limit reached";
      return false;
   }

   if(IsDailyLossLimitHit())
   {
      reason = "Daily loss limit reached";
      return false;
   }

   if(InpMaxConsecutiveLosses > 0 && g_consecutive_losses >= InpMaxConsecutiveLosses)
   {
      reason = "Consecutive loss limit reached";
      return false;
   }

   if(InpLossCooldownThreshold > 0 && InpLossCooldownBars > 0 &&
      g_consecutive_losses >= InpLossCooldownThreshold && g_last_loss_deal_time > 0)
   {
      int loss_shift = iBarShift(g_symbol, InpSignalTimeframe, g_last_loss_deal_time, true);
      if(loss_shift >= 0 && loss_shift < InpLossCooldownBars)
      {
         reason = "Waiting after consecutive losses";
         return false;
      }
   }

   if(InpMinBarsBetweenTrades > 0 && g_last_trade_bar_time > 0)
   {
      int shift = iBarShift(g_symbol, InpSignalTimeframe, g_last_trade_bar_time, true);
      if(shift >= 0 && shift < InpMinBarsBetweenTrades)
      {
         reason = "Waiting for trade cooldown";
         return false;
      }
   }

   double stop_points = MathAbs(snapshot.entry - snapshot.sl) / g_point;
   if(stop_points > InpMaxStopPoints)
   {
      reason = "Stop distance is too large";
      return false;
   }

   if(stop_points < InpMinStopPoints)
   {
      reason = "Stop distance is too small";
      return false;
   }

   double reward_points = MathAbs(snapshot.tp - snapshot.entry) / g_point;
   double reward_risk = reward_points / stop_points;
   double min_reward_risk = (snapshot.regime == REGIME_RANGE ? InpMinRangeTradeR : InpMinTrendTradeR);
   if(min_reward_risk > 0.0 && reward_risk < min_reward_risk)
   {
      reason = "Reward/risk is too low";
      return false;
   }

   reason = "";
   return true;
}

double CalculateOrderLots(double entry, double sl, string &reason)
{
   double lots = InpFixedLot;

   if(InpLotMode == LOT_RISK_PERCENT)
   {
      double risk_money = AccountInfoDouble(ACCOUNT_EQUITY) * EffectiveRiskPercent() / 100.0;
      double stop_distance = MathAbs(entry - sl);
      double tick_size = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_VALUE);

      if(stop_distance <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0)
      {
         reason = "Cannot calculate risk lot";
         return 0.0;
      }

      double money_per_lot = (stop_distance / tick_size) * tick_value;
      if(money_per_lot <= 0.0)
      {
         reason = "Invalid money per lot";
         return 0.0;
      }

      lots = risk_money / money_per_lot;
   }

   double min_lot = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN);

   if(lots < min_lot)
   {
      if(InpAllowMinLotIfRiskTooLow)
         lots = min_lot;
      else
      {
         reason = "Calculated lot is below broker minimum";
         return 0.0;
      }
   }

   lots = NormalizeVolume(lots);

   double actual_risk_percent = EstimateRiskPercent(entry, sl, lots);
   if(InpMaxActualRiskPercent > 0.0 && actual_risk_percent > InpMaxActualRiskPercent)
   {
      reason = StringFormat("Actual risk %.2f%% exceeds limit %.2f%%",
                            actual_risk_percent, InpMaxActualRiskPercent);
      return 0.0;
   }

   if(lots <= 0.0)
   {
      reason = "Invalid lot size";
      return 0.0;
   }

   reason = "";
   return lots;
}

double EstimateRiskPercent(double entry, double sl, double lots)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double tick_size = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_VALUE);
   double stop_distance = MathAbs(entry - sl);

   if(equity <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0 || stop_distance <= 0.0 || lots <= 0.0)
      return 0.0;

   double risk_money = (stop_distance / tick_size) * tick_value * lots;
   return risk_money / equity * 100.0;
}

bool SendMarketOrder(ENUM_TRADE_SIGNAL signal, double lots, double sl, double tp, string reason)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   bool is_buy = signal == SIGNAL_BUY;
   double price = is_buy ? SymbolInfoDouble(g_symbol, SYMBOL_ASK) : SymbolInfoDouble(g_symbol, SYMBOL_BID);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = g_symbol;
   request.magic = InpMagicNumber;
   request.volume = lots;
   request.type = is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = NormalizeDouble(price, g_digits);
   request.sl = NormalizeDouble(sl, g_digits);
   request.tp = NormalizeDouble(tp, g_digits);
   request.deviation = InpMaxSlippagePoints;
   request.type_filling = PreferredFillingMode();
   request.type_time = ORDER_TIME_GTC;
   request.comment = ShortComment(reason);

   ResetLastError();
   bool sent = OrderSend(request, result);
   if(sent && IsSuccessfulRetcode(result.retcode))
   {
      g_last_trade_result = StringFormat("%s %.2f lots, SL %.2f, TP %.2f",
                                         is_buy ? "BUY" : "SELL", lots, request.sl, request.tp);
      Print("Order opened: ", g_last_trade_result, " | ", reason);
      return true;
   }

   g_last_trade_result = StringFormat("Order failed: retcode=%d error=%d", result.retcode, GetLastError());
   Print(g_last_trade_result, " | ", result.comment);
   return false;
}

void CloseAllManagedPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != g_symbol)
         continue;

      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double volume = PositionGetDouble(POSITION_VOLUME);
      bool is_buy_position = position_type == POSITION_TYPE_BUY;

      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);

      request.action = TRADE_ACTION_DEAL;
      request.symbol = g_symbol;
      request.position = ticket;
      request.magic = InpMagicNumber;
      request.volume = volume;
      request.type = is_buy_position ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      request.price = NormalizeDouble(is_buy_position ? SymbolInfoDouble(g_symbol, SYMBOL_BID)
                                                      : SymbolInfoDouble(g_symbol, SYMBOL_ASK), g_digits);
      request.deviation = InpMaxSlippagePoints;
      request.type_filling = PreferredFillingMode();
      request.type_time = ORDER_TIME_GTC;
      request.comment = "Panel close";

      ResetLastError();
      bool sent = OrderSend(request, result);
      if(sent && IsSuccessfulRetcode(result.retcode))
         Print("Closed position #", ticket);
      else
         Print("Close failed #", ticket, " retcode=", result.retcode, " error=", GetLastError());
   }

   g_last_trade_result = "Close command sent";
}

void ManageOpenPositions(bool is_new_entry_bar)
{
   if(!InpUseBreakevenStop && !InpUseAtrTrailingStop)
      return;
   if(InpManageStopsOnEntryBarOnly && !is_new_entry_bar)
      return;

   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_atr_handle, 0, 0, 3, atr) < 3 || atr[1] <= 0.0)
      return;

   double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double min_stop = ((double)SymbolInfoInteger(g_symbol, SYMBOL_TRADE_STOPS_LEVEL) + 5.0) * g_point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != g_symbol)
         continue;

      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool is_buy_position = position_type == POSITION_TYPE_BUY;
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_sl = PositionGetDouble(POSITION_SL);
      double current_tp = PositionGetDouble(POSITION_TP);
      double risk_distance = EstimatePositionInitialRisk(open_price, current_sl, current_tp);
      if(risk_distance <= 0.0)
         continue;

      double profit_distance = is_buy_position ? bid - open_price : open_price - ask;
      double r_multiple = profit_distance / risk_distance;
      if(r_multiple <= 0.0)
         continue;

      double candidate_sl = current_sl;
      string adjust_reason = "";

      if(InpUseBreakevenStop && r_multiple >= InpBreakevenTriggerR)
      {
         double breakeven_sl = open_price + (is_buy_position ? 1.0 : -1.0) *
                               InpBreakevenBufferPoints * g_point;
         if(IsStopImprovement(is_buy_position, current_sl, breakeven_sl))
         {
            candidate_sl = breakeven_sl;
            adjust_reason = "breakeven";
         }
      }

      if(InpUseAtrTrailingStop && r_multiple >= InpAtrTrailTriggerR)
      {
         double trail_distance = atr[1] * MathMax(0.10, InpAtrTrailMultiplier);
         double trailing_sl = is_buy_position ? bid - trail_distance : ask + trail_distance;
         if(IsStopImprovement(is_buy_position, candidate_sl, trailing_sl))
         {
            candidate_sl = trailing_sl;
            adjust_reason = "ATR trail";
         }
      }

      candidate_sl = ClampManagedStop(is_buy_position, candidate_sl, bid, ask, min_stop);
      if(adjust_reason != "" && IsStopImprovement(is_buy_position, current_sl, candidate_sl))
         ModifyPositionStop(ticket, candidate_sl, current_tp, adjust_reason);
   }
}

double EstimatePositionInitialRisk(double open_price, double current_sl, double current_tp)
{
   double risk_from_target = 0.0;
   if(current_tp > 0.0)
      risk_from_target = MathAbs(current_tp - open_price) / MathMax(0.10, EffectiveTrendRewardRisk());

   double risk_from_stop = 0.0;
   if(current_sl > 0.0)
      risk_from_stop = MathAbs(open_price - current_sl);

   if(risk_from_target > 0.0)
      return risk_from_target;
   return risk_from_stop;
}

bool IsStopImprovement(bool is_buy_position, double current_sl, double candidate_sl)
{
   if(candidate_sl <= 0.0)
      return false;
   if(current_sl <= 0.0)
      return true;
   double min_step = MathMax(g_point, InpMinManagedStopStepPoints * g_point);
   if(is_buy_position)
      return candidate_sl > current_sl + min_step;
   return candidate_sl < current_sl - min_step;
}

double ClampManagedStop(bool is_buy_position, double candidate_sl, double bid, double ask, double min_stop)
{
   if(candidate_sl <= 0.0)
      return 0.0;

   if(is_buy_position)
      candidate_sl = MathMin(candidate_sl, bid - min_stop);
   else
      candidate_sl = MathMax(candidate_sl, ask + min_stop);

   return NormalizeDouble(candidate_sl, g_digits);
}

bool ModifyPositionStop(ulong ticket, double sl, double tp, string reason)
{
   if(sl <= 0.0 || !PositionSelectByTicket(ticket))
      return false;

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_SLTP;
   request.symbol = g_symbol;
   request.position = ticket;
   request.magic = InpMagicNumber;
   request.sl = NormalizeDouble(sl, g_digits);
   request.tp = NormalizeDouble(tp, g_digits);

   ResetLastError();
   bool sent = OrderSend(request, result);
   if(sent && IsSuccessfulRetcode(result.retcode))
   {
      g_last_trade_result = StringFormat("Moved SL to %.2f (%s)", request.sl, reason);
      Print("Position #", ticket, " ", g_last_trade_result);
      return true;
   }

   Print("SL modify failed #", ticket, " retcode=", result.retcode, " error=", GetLastError());
   return false;
}

ENUM_ORDER_TYPE_FILLING PreferredFillingMode()
{
   int filling = (int)SymbolInfoInteger(g_symbol, SYMBOL_FILLING_MODE);

   if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
   if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;

   return ORDER_FILLING_RETURN;
}

bool IsSuccessfulRetcode(uint retcode)
{
   return retcode == TRADE_RETCODE_DONE ||
          retcode == TRADE_RETCODE_DONE_PARTIAL ||
          retcode == TRADE_RETCODE_PLACED;
}

string ShortComment(string text)
{
   if(StringLen(text) <= 30)
      return text;
   return StringSubstr(text, 0, 30);
}

void RefreshRiskStats()
{
   datetime now = TimeCurrent();
   if(now == g_last_history_check)
      return;
   g_last_history_check = now;

   MqlDateTime day;
   TimeToStruct(now, day);
   day.hour = 0;
   day.min = 0;
   day.sec = 0;
   datetime day_start = StructToTime(day);

   g_daily_profit = 0.0;
   g_daily_trades = 0;
   g_last_loss_deal_time = 0;

   if(HistorySelect(day_start, now))
   {
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong deal_ticket = HistoryDealGetTicket(i);
         if(deal_ticket == 0)
            continue;

         if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != g_symbol)
            continue;

         if((long)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != InpMagicNumber)
            continue;

         ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
         if(entry_type == DEAL_ENTRY_IN)
            g_daily_trades++;

         if(entry_type == DEAL_ENTRY_OUT || entry_type == DEAL_ENTRY_INOUT)
         {
            double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT) +
                                 HistoryDealGetDouble(deal_ticket, DEAL_SWAP) +
                                 HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
            g_daily_profit += deal_profit;
            if(deal_profit < 0.0)
            {
               datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
               if(deal_time > g_last_loss_deal_time)
                  g_last_loss_deal_time = deal_time;
            }
         }
      }
   }

   g_consecutive_losses = CalculateConsecutiveLosses(day_start);
}

int CalculateConsecutiveLosses(datetime from_time)
{
   if(!HistorySelect(from_time, TimeCurrent()))
      return 0;

   int losses = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;

      if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != g_symbol)
         continue;

      if((long)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != InpMagicNumber)
         continue;

      ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_type != DEAL_ENTRY_OUT && entry_type != DEAL_ENTRY_INOUT)
         continue;

      double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT) +
                      HistoryDealGetDouble(deal_ticket, DEAL_SWAP) +
                      HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);

      if(profit < 0.0)
         losses++;
      else
         break;
   }

   return losses;
}

bool IsDailyLossLimitHit()
{
   bool percent_hit = false;
   bool money_hit = false;

   if(InpMaxDailyLossPercent > 0.0)
   {
      double limit = AccountInfoDouble(ACCOUNT_BALANCE) * InpMaxDailyLossPercent / 100.0;
      percent_hit = g_daily_profit <= -limit;
   }

   if(InpMaxDailyLossMoney > 0.0)
      money_hit = g_daily_profit <= -InpMaxDailyLossMoney;

   return percent_hit || money_hit;
}

int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) == g_symbol &&
         (long)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         count++;
   }

   return count;
}

bool IsWithinTradeHours()
{
   MqlDateTime current;
   TimeToStruct(TimeCurrent(), current);

   int start_hour = MathMax(0, MathMin(23, InpTradeStartHour));
   int end_hour = MathMax(0, MathMin(23, InpTradeEndHour));

   if(start_hour == end_hour)
      return true;

   if(start_hour < end_hour)
      return current.hour >= start_hour && current.hour < end_hour;

   return current.hour >= start_hour || current.hour < end_hour;
}

bool IsNewSignalBar()
{
   datetime bar_time = iTime(g_symbol, InpSignalTimeframe, 0);
   if(bar_time <= 0)
      return false;

   if(bar_time == g_last_signal_bar_time)
      return false;

   g_last_signal_bar_time = bar_time;
   return true;
}

bool IsNewEntryBar()
{
   datetime bar_time = iTime(g_symbol, InpEntryTimeframe, 0);
   if(bar_time <= 0)
      return false;

   if(bar_time == g_last_entry_bar_time)
      return false;

   g_last_entry_bar_time = bar_time;
   return true;
}

void RefreshSymbolMeta()
{
   g_digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
   g_point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
}

double CurrentSpreadPoints()
{
   double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   if(g_point <= 0.0)
      return 0.0;
   return (ask - bid) / g_point;
}

double EffectiveRiskPercent()
{
   return MathMax(0.01, InpRiskPercent * g_profile_risk_multiplier);
}

double EffectiveTrendRewardRisk()
{
   if(g_profile_name == "Conservative")
      return MathMax(1.50, InpTrendRewardRisk);
   if(g_profile_name == "Aggressive")
      return MathMax(1.30, InpTrendRewardRisk * 0.90);
   return InpTrendRewardRisk;
}

double NormalizeVolume(double lots)
{
   double min_lot = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_STEP);

   if(step <= 0.0)
      step = 0.01;

   lots = MathMax(min_lot, MathMin(max_lot, lots));
   lots = MathFloor(lots / step) * step;

   int lot_digits = 2;
   if(step < 0.01)
      lot_digits = 3;
   if(step < 0.001)
      lot_digits = 4;

   return NormalizeDouble(lots, lot_digits);
}

double AverageAtr(double &atr[], int start_index, int count)
{
   double sum = 0.0;
   int used = 0;

   for(int i = start_index; i < start_index + count && i < ArraySize(atr); i++)
   {
      if(atr[i] > 0.0)
      {
         sum += atr[i];
         used++;
      }
   }

   if(used == 0)
      return 0.0;

   return sum / used;
}

double TrueRange(MqlRates &rates[], int index)
{
   if(index < 0 || index >= ArraySize(rates))
      return 0.0;

   double high_low = rates[index].high - rates[index].low;
   if(index + 1 >= ArraySize(rates))
      return high_low;

   double high_close = MathAbs(rates[index].high - rates[index + 1].close);
   double low_close = MathAbs(rates[index].low - rates[index + 1].close);
   return MathMax(high_low, MathMax(high_close, low_close));
}

double AverageTrueRangeFromRates(MqlRates &rates[], int start_index, int period)
{
   double sum = 0.0;
   int used = 0;

   for(int i = start_index; i < start_index + period && i < ArraySize(rates) - 1; i++)
   {
      double tr = TrueRange(rates, i);
      if(tr > 0.0)
      {
         sum += tr;
         used++;
      }
   }

   if(used <= 0)
      return 0.0;

   return sum / used;
}

double CalculateChoppiness(MqlRates &rates[], int period)
{
   if(period < 2 || ArraySize(rates) <= period + 2)
      return 0.0;

   double sum_tr = 0.0;
   for(int i = 1; i <= period; i++)
      sum_tr += TrueRange(rates, i);

   double high = HighestHigh(rates, 1, period);
   double low = LowestLow(rates, 1, period);
   double range = high - low;

   if(sum_tr <= 0.0 || range <= 0.0)
      return 0.0;

   return 100.0 * MathLog(sum_tr / range) / MathLog((double)period);
}

double CalculateEfficiencyRatio(MqlRates &rates[], int period)
{
   if(period < 2 || ArraySize(rates) <= period + 2)
      return 1.0;

   double direction = MathAbs(rates[1].close - rates[period + 1].close);
   double volatility = 0.0;

   for(int i = 1; i <= period; i++)
      volatility += MathAbs(rates[i].close - rates[i + 1].close);

   if(volatility <= 0.0)
      return 0.0;

   return direction / volatility;
}

double CalculateSessionVwap(MqlRates &rates[])
{
   if(ArraySize(rates) < 3)
      return 0.0;

   MqlDateTime signal_day;
   TimeToStruct(rates[1].time, signal_day);

   double sum_pv = 0.0;
   double sum_volume = 0.0;

   for(int i = 1; i < ArraySize(rates); i++)
   {
      MqlDateTime bar_day;
      TimeToStruct(rates[i].time, bar_day);
      if(bar_day.year != signal_day.year || bar_day.mon != signal_day.mon || bar_day.day != signal_day.day)
         break;

      double volume = (double)rates[i].tick_volume;
      if(volume <= 0.0)
         volume = 1.0;

      double typical = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      sum_pv += typical * volume;
      sum_volume += volume;
   }

   if(sum_volume <= 0.0)
      return 0.0;

   return sum_pv / sum_volume;
}

int CalculateSupertrendDirection()
{
   if(!InpUseSupertrendFilter)
      return 0;

   static datetime cached_bar_time = 0;
   static int cached_direction = 0;

   datetime higher_closed_bar = iTime(g_symbol, InpHigherTimeframe, 1);
   if(higher_closed_bar > 0 && higher_closed_bar == cached_bar_time)
      return cached_direction;

   int period = MathMax(2, InpSupertrendPeriod);
   int bars_needed = period + 80;
   MqlRates higher_rates[];
   ArraySetAsSeries(higher_rates, true);
   int copied = CopyRates(g_symbol, InpHigherTimeframe, 0, bars_needed, higher_rates);
   if(copied < period + 20)
      return cached_direction;

   int oldest = copied - period - 1;
   double final_upper = 0.0;
   double final_lower = 0.0;
   int trend = 0;

   for(int i = oldest; i >= 1; i--)
   {
      double atr_value = AverageTrueRangeFromRates(higher_rates, i, period);
      if(atr_value <= 0.0)
         continue;

      double mid = (higher_rates[i].high + higher_rates[i].low) / 2.0;
      double basic_upper = mid + InpSupertrendMultiplier * atr_value;
      double basic_lower = mid - InpSupertrendMultiplier * atr_value;

      if(final_upper == 0.0 || final_lower == 0.0)
      {
         final_upper = basic_upper;
         final_lower = basic_lower;
         trend = (higher_rates[i].close >= mid ? 1 : -1);
         continue;
      }

      double previous_upper = final_upper;
      double previous_lower = final_lower;
      int previous_trend = trend;

      if(basic_upper < previous_upper || higher_rates[i + 1].close > previous_upper)
         final_upper = basic_upper;
      else
         final_upper = previous_upper;

      if(basic_lower > previous_lower || higher_rates[i + 1].close < previous_lower)
         final_lower = basic_lower;
      else
         final_lower = previous_lower;

      if(previous_trend <= 0 && higher_rates[i].close > final_upper)
         trend = 1;
      else if(previous_trend >= 0 && higher_rates[i].close < final_lower)
         trend = -1;
      else
         trend = previous_trend;
   }

   if(higher_closed_bar > 0)
      cached_bar_time = higher_closed_bar;
   cached_direction = trend;
   return cached_direction;
}

bool HasUsableRange(MqlRates &rates[], double atr_value)
{
   int lookback = MathMax(12, InpRangeLookbackBars);
   if(ArraySize(rates) <= lookback + 2 || atr_value <= 0.0)
      return false;

   double high = HighestHigh(rates, 1, lookback);
   double low = LowestLow(rates, 1, lookback);
   double width_atr = (high - low) / atr_value;

   return width_atr >= InpRangeMinWidthAtr && width_atr <= InpRangeMaxWidthAtr;
}

bool IsBullishLiquiditySweep(MqlRates &rates[], double atr_value)
{
   int lookback = MathMax(6, InpSweepLookbackBars);
   if(ArraySize(rates) <= lookback + 2 || atr_value <= 0.0)
      return false;

   double prior_low = LowestLow(rates, 2, lookback);
   double buffer = atr_value * MathMax(0.0, InpSweepBufferAtr);

   return rates[1].low <= prior_low + buffer && rates[1].close > prior_low;
}

bool IsBearishLiquiditySweep(MqlRates &rates[], double atr_value)
{
   int lookback = MathMax(6, InpSweepLookbackBars);
   if(ArraySize(rates) <= lookback + 2 || atr_value <= 0.0)
      return false;

   double prior_high = HighestHigh(rates, 2, lookback);
   double buffer = atr_value * MathMax(0.0, InpSweepBufferAtr);

   return rates[1].high >= prior_high - buffer && rates[1].close < prior_high;
}

double HighestHigh(MqlRates &rates[], int start_index, int count)
{
   double value = rates[start_index].high;
   for(int i = start_index; i < start_index + count && i < ArraySize(rates); i++)
      value = MathMax(value, rates[i].high);
   return value;
}

double LowestLow(MqlRates &rates[], int start_index, int count)
{
   double value = rates[start_index].low;
   for(int i = start_index; i < start_index + count && i < ArraySize(rates); i++)
      value = MathMin(value, rates[i].low);
   return value;
}

bool IsBullishRejection(const MqlRates &bar)
{
   double body = MathAbs(bar.close - bar.open);
   double lower_wick = MathMin(bar.open, bar.close) - bar.low;
   if(body < g_point)
      body = g_point;

   return bar.close > bar.open || lower_wick >= body * 1.20;
}

bool IsBearishRejection(const MqlRates &bar)
{
   double body = MathAbs(bar.close - bar.open);
   double upper_wick = bar.high - MathMax(bar.open, bar.close);
   if(body < g_point)
      body = g_point;

   return bar.close < bar.open || upper_wick >= body * 1.20;
}

string RegimeToString(ENUM_MARKET_REGIME regime)
{
   if(regime == REGIME_TREND_UP)
      return "Trend Up";
   if(regime == REGIME_TREND_DOWN)
      return "Trend Down";
   if(regime == REGIME_RANGE)
      return "Range";
   return "Unclear";
}

string SignalToString(ENUM_TRADE_SIGNAL signal)
{
   if(signal == SIGNAL_BUY)
      return "BUY";
   if(signal == SIGNAL_SELL)
      return "SELL";
   return "NONE";
}

string TrendBiasToString(int trend)
{
   if(trend > 0)
      return "Bull";
   if(trend < 0)
      return "Bear";
   return "Flat";
}

void TrackDiagnostics(const StrategySnapshot &snapshot)
{
   g_diag_bars++;

   if(snapshot.regime == REGIME_TREND_UP)
      g_diag_trend_up++;
   else if(snapshot.regime == REGIME_TREND_DOWN)
      g_diag_trend_down++;
   else if(snapshot.regime == REGIME_RANGE)
      g_diag_range++;
   else
      g_diag_unclear++;

   if(snapshot.signal == SIGNAL_BUY)
      g_diag_buy_signals++;
   else if(snapshot.signal == SIGNAL_SELL)
      g_diag_sell_signals++;

   if(InpDebugSignalLog && (snapshot.signal != SIGNAL_NONE || g_diag_bars % 96 == 0))
   {
      Print("Signal check #", g_diag_bars,
            " regime=", RegimeToString(snapshot.regime),
            " signal=", SignalToString(snapshot.signal),
            " ADX=", DoubleToString(snapshot.adx, 1),
            " RSI=", DoubleToString(snapshot.rsi, 1),
            " ATR=", DoubleToString(snapshot.atr, g_digits),
            " spread=", DoubleToString(snapshot.spread_points, 0),
            " reason=", snapshot.reason);
   }
}

void TrackBlockedTrade(const string reason)
{
   if(reason == "Auto trading is paused")
      g_diag_block_auto_paused++;
   else if(reason == "Trading is disabled by terminal or account")
      g_diag_block_trade_disabled++;
   else if(reason == "Symbol trading mode is disabled")
      g_diag_block_symbol_disabled++;
   else if(reason == "Outside configured trade hours")
      g_diag_block_hours++;
   else if(reason == "Spread is too high")
      g_diag_block_spread++;
   else if(reason == "Long trades are disabled" || reason == "Short trades are disabled")
      g_diag_block_direction++;
   else if(reason == "Maximum open positions reached")
      g_diag_block_open_positions++;
   else if(reason == "Daily trade limit reached")
      g_diag_block_daily_trade_limit++;
   else if(reason == "Daily loss limit reached")
      g_diag_block_daily_loss++;
   else if(reason == "Consecutive loss limit reached")
      g_diag_block_consecutive_loss++;
   else if(reason == "Waiting for trade cooldown")
      g_diag_block_cooldown++;
   else if(reason == "Waiting after consecutive losses")
      g_diag_block_cooldown++;
   else if(reason == "Stop distance is too large")
      g_diag_block_stop_too_large++;
   else if(reason == "Stop distance is too small")
      g_diag_block_stop_too_small++;
   else if(reason == "Reward/risk is too low")
      g_diag_block_reward_risk++;
   else if(StringFind(reason, "Actual risk") == 0)
      g_diag_block_actual_risk++;
   else if(reason == "Cannot calculate risk lot" ||
           reason == "Invalid money per lot" ||
           reason == "Calculated lot is below broker minimum" ||
           reason == "Invalid lot size")
      g_diag_block_lot++;
   else
      g_diag_block_unknown++;
}

void PrintDiagnostics()
{
   if(g_diag_bars <= 0)
      return;

   Print("Diagnostics summary | bars=", g_diag_bars,
         " trendUp=", g_diag_trend_up,
         " trendDown=", g_diag_trend_down,
         " range=", g_diag_range,
         " unclear=", g_diag_unclear,
         " buySignals=", g_diag_buy_signals,
         " sellSignals=", g_diag_sell_signals,
         " blocked=", g_diag_blocked,
         " attempts=", g_diag_order_attempts,
         " success=", g_diag_order_success);

   Print("Block summary | autoPaused=", g_diag_block_auto_paused,
         " tradeDisabled=", g_diag_block_trade_disabled,
         " symbolDisabled=", g_diag_block_symbol_disabled,
         " hours=", g_diag_block_hours,
         " spread=", g_diag_block_spread,
         " direction=", g_diag_block_direction,
         " openPositions=", g_diag_block_open_positions,
         " dailyTradeLimit=", g_diag_block_daily_trade_limit,
         " dailyLoss=", g_diag_block_daily_loss,
         " consecutiveLoss=", g_diag_block_consecutive_loss,
         " cooldown=", g_diag_block_cooldown,
         " stopTooLarge=", g_diag_block_stop_too_large,
         " stopTooSmall=", g_diag_block_stop_too_small,
         " rewardRisk=", g_diag_block_reward_risk,
         " lot=", g_diag_block_lot,
         " actualRisk=", g_diag_block_actual_risk,
         " unknown=", g_diag_block_unknown);
}

void CreatePanel()
{
   DeletePanel();

   int x = InpPanelX;
   int y = InpPanelY;
   int width = 376;
   int height = 462;

   CreateRect("BG", x, y, width, height, C'18,24,33', C'64,78,96');
   CreateLabel("TITLE", x + 14, y + 10, "XAUUSD Regime EA", 11, clrWhite);
   CreateLabel("SUBTITLE", x + 14, y + 31, "Trend-following + range-reversal", 8, C'151,164,183');

   int row_y = y + 58;
   int gap = 19;
   CreateMetricRow(0, row_y + gap * 0, "Auto", "");
   CreateMetricRow(1, row_y + gap * 1, "Profile", "");
   CreateMetricRow(2, row_y + gap * 2, "Balance", "");
   CreateMetricRow(3, row_y + gap * 3, "Equity / Float", "");
   CreateMetricRow(4, row_y + gap * 4, "Regime", "");
   CreateMetricRow(5, row_y + gap * 5, "Signal", "");
   CreateMetricRow(6, row_y + gap * 6, "Reason", "");
   CreateMetricRow(7, row_y + gap * 7, "Spread", "");
   CreateMetricRow(8, row_y + gap * 8, "ADX / RSI", "");
   CreateMetricRow(9, row_y + gap * 9, "ATR", "");
   CreateMetricRow(10, row_y + gap * 10, "Chop / ER", "");
   CreateMetricRow(11, row_y + gap * 11, "VWAP / H1", "");
   CreateMetricRow(12, row_y + gap * 12, "Positions", "");
   CreateMetricRow(13, row_y + gap * 13, "Today P/L", "");
   CreateMetricRow(14, row_y + gap * 14, "Daily trades", "");
   CreateMetricRow(15, row_y + gap * 15, "Last action", "");

   CreateButton("BTN_SAFE", x + 14, y + 394, 104, 25, "Safe", C'35,134,90');
   CreateButton("BTN_STANDARD", x + 126, y + 394, 104, 25, "Standard", C'84,100,122');
   CreateButton("BTN_AGGRESSIVE", x + 238, y + 394, 122, 25, "Aggressive", C'194,120,3');
   CreateButton("BTN_AUTO", x + 14, y + 426, 168, 25, "Pause", C'37,99,235');
   CreateButton("BTN_CLOSE", x + 192, y + 426, 168, 25, "Close Positions", C'220,53,69');

   UpdatePanel();
   ChartRedraw(0);
}

void CreateMetricRow(int index, int y, string label, string value)
{
   int x = InpPanelX;
   CreateLabel("L" + IntegerToString(index), x + 14, y, label, 8, C'151,164,183');
   CreateLabel("V" + IntegerToString(index), x + 136, y, value, 8, clrWhite);
}

void CreateRect(string id, int x, int y, int w, int h, color bg, color border)
{
   string name = PANEL_PREFIX + id;
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void CreateLabel(string id, int x, int y, string text, int size, color clr)
{
   string name = PANEL_PREFIX + id;
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, "Segoe UI");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void CreateButton(string id, int x, int y, int w, int h, string text, color bg)
{
   string name = PANEL_PREFIX + id;
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'55,65,81');
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Segoe UI");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void UpdatePanel()
{
   if(!IsPanelEnabled())
      return;

   StrategySnapshot snapshot;
   ResetSnapshot(snapshot);
   BuildStrategySnapshot(snapshot);

   SetMetricValue(0, g_auto_enabled ? "ON" : "PAUSED", g_auto_enabled ? C'74,222,128' : C'248,113,113');
   SetMetricValue(1, g_profile_name + " / risk " + DoubleToString(EffectiveRiskPercent(), 2) + "%", clrWhite);
   double floating_profit = AccountInfoDouble(ACCOUNT_PROFIT);
   SetMetricValue(2, DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2), clrWhite);
   SetMetricValue(3, DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + " / " +
                  DoubleToString(floating_profit, 2), floating_profit >= 0.0 ? C'74,222,128' : C'248,113,113');
   SetMetricValue(4, RegimeToString(snapshot.regime), RegimeColor(snapshot.regime));
   SetMetricValue(5, SignalToString(snapshot.signal), SignalColor(snapshot.signal));
   SetMetricValue(6, TrimForPanel(snapshot.reason, 33), C'226,232,240');
   SetMetricValue(7, DoubleToString(CurrentSpreadPoints(), 0) + " pts", CurrentSpreadPoints() <= InpMaxSpreadPoints ? clrWhite : C'248,113,113');
   SetMetricValue(8, DoubleToString(snapshot.adx, 1) + " / " + DoubleToString(snapshot.rsi, 1), clrWhite);
   SetMetricValue(9, DoubleToString(snapshot.atr, g_digits), clrWhite);
   SetMetricValue(10, DoubleToString(snapshot.choppiness, 1) + " / " +
                  DoubleToString(snapshot.efficiency, 2), clrWhite);
   SetMetricValue(11, DoubleToString(snapshot.vwap_deviation_atr, 2) + " ATR / " +
                  TrendBiasToString(snapshot.higher_trend), clrWhite);
   SetMetricValue(12, IntegerToString(CountOpenPositions()) + " / " + IntegerToString(InpMaxOpenPositions), clrWhite);
   SetMetricValue(13, DoubleToString(g_daily_profit, 2), g_daily_profit >= 0.0 ? C'74,222,128' : C'248,113,113');
   SetMetricValue(14, IntegerToString(g_daily_trades) + " / " + IntegerToString(InpMaxTradesPerDay), clrWhite);
   SetMetricValue(15, TrimForPanel(g_last_trade_result, 33), C'226,232,240');

   string auto_button = PANEL_PREFIX + "BTN_AUTO";
   if(ObjectFind(0, auto_button) >= 0)
   {
      ObjectSetString(0, auto_button, OBJPROP_TEXT, g_auto_enabled ? "Pause" : "Start");
      ObjectSetInteger(0, auto_button, OBJPROP_BGCOLOR, g_auto_enabled ? C'37,99,235' : C'35,134,90');
   }
}

bool IsPanelEnabled()
{
   if(!InpShowPanel)
      return false;

   if(InpDisablePanelInTester && (bool)MQLInfoInteger(MQL_TESTER))
      return false;

   return true;
}

void SetMetricValue(int index, string text, color clr)
{
   string name = PANEL_PREFIX + "V" + IntegerToString(index);
   if(ObjectFind(0, name) < 0)
      return;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

color RegimeColor(ENUM_MARKET_REGIME regime)
{
   if(regime == REGIME_TREND_UP)
      return C'74,222,128';
   if(regime == REGIME_TREND_DOWN)
      return C'248,113,113';
   if(regime == REGIME_RANGE)
      return C'96,165,250';
   return C'251,191,36';
}

color SignalColor(ENUM_TRADE_SIGNAL signal)
{
   if(signal == SIGNAL_BUY)
      return C'74,222,128';
   if(signal == SIGNAL_SELL)
      return C'248,113,113';
   return C'203,213,225';
}

string TrimForPanel(string text, int max_len)
{
   if(StringLen(text) <= max_len)
      return text;
   return StringSubstr(text, 0, max_len - 3) + "...";
}

void DeletePanel()
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, PANEL_PREFIX) == 0)
         ObjectDelete(0, name);
   }
}
