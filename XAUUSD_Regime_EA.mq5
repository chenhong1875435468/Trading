#property strict
#property version   "0.10"
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
input ENUM_TIMEFRAMES      InpHigherTimeframe          = PERIOD_H1;
input long                 InpMagicNumber              = 26052201;
input ENUM_TRADE_DIRECTION InpTradeDirection           = DIRECTION_BOTH;
input bool                 InpStartAutoTrading         = true;

input ENUM_LOT_MODE        InpLotMode                  = LOT_FIXED;
input double               InpFixedLot                 = 0.01;
input double               InpRiskPercent              = 0.50;
input bool                 InpAllowMinLotIfRiskTooLow  = true;

input int                  InpFastEmaPeriod            = 21;
input int                  InpSlowEmaPeriod            = 55;
input int                  InpAdxPeriod                = 14;
input double               InpTrendAdxThreshold        = 25.0;
input double               InpRangeAdxThreshold        = 20.0;
input int                  InpRsiPeriod                = 14;
input double               InpRsiOverbought            = 70.0;
input double               InpRsiOversold              = 30.0;
input int                  InpAtrPeriod                = 14;
input double               InpMinAtrFactor             = 0.85;
input int                  InpBandsPeriod              = 20;
input double               InpBandsDeviation           = 2.0;
input int                  InpRangeLookbackBars        = 48;
input double               InpRangeMaxWidthAtr         = 7.0;
input double               InpRangeEmaGapAtr           = 0.55;

input double               InpTrendAtrStopMultiplier   = 1.60;
input double               InpRangeAtrStopBuffer       = 0.35;
input double               InpTrendRewardRisk          = 1.80;
input double               InpRangeRewardRisk          = 1.10;
input int                  InpMinStopPoints            = 80;
input int                  InpMaxStopPoints            = 1800;

input int                  InpMaxSpreadPoints          = 350;
input int                  InpMaxSlippagePoints        = 30;
input int                  InpMaxOpenPositions         = 1;
input int                  InpMaxTradesPerDay          = 3;
input double               InpMaxDailyLossPercent      = 3.0;
input double               InpMaxDailyLossMoney        = 3.0;
input int                  InpMaxConsecutiveLosses     = 3;
input int                  InpMinBarsBetweenTrades     = 2;
input bool                 InpUseTradeHours            = true;
input int                  InpTradeStartHour           = 7;
input int                  InpTradeEndHour             = 23;

input bool                 InpShowPanel                = true;
input int                  InpPanelX                   = 12;
input int                  InpPanelY                   = 24;

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
   double             spread_points;
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
datetime g_last_history_check = 0;
string   g_last_reason = "Waiting";
string   g_last_trade_result = "No trade yet";
double   g_daily_profit = 0.0;
int      g_daily_trades = 0;
int      g_consecutive_losses = 0;

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

   if(InpShowPanel)
      CreatePanel();

   EventSetTimer(1);
   Print("EA initialized for ", g_symbol, " on ", EnumToString(InpSignalTimeframe));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ReleaseIndicatorHandles();
   DeletePanel();
}

void OnTimer()
{
   RefreshRiskStats();
   UpdatePanel();
}

void OnTick()
{
   if(_Symbol != g_symbol && InpTradeSymbol == "")
      return;

   RefreshSymbolMeta();

   StrategySnapshot snapshot;
   ResetSnapshot(snapshot);

   if(!BuildStrategySnapshot(snapshot))
   {
      g_last_reason = "Waiting for enough indicator data";
      UpdatePanel();
      return;
   }

   g_last_reason = snapshot.reason;

   if(!IsNewSignalBar())
   {
      UpdatePanel();
      return;
   }

   if(snapshot.signal == SIGNAL_NONE)
   {
      UpdatePanel();
      return;
   }

   string block_reason = "";
   if(!CanOpenTrade(snapshot, block_reason))
   {
      g_last_trade_result = "Blocked: " + block_reason;
      g_last_reason = block_reason;
      UpdatePanel();
      return;
   }

   double lots = CalculateOrderLots(snapshot.entry, snapshot.sl, block_reason);
   if(lots <= 0.0)
   {
      g_last_trade_result = "Blocked: " + block_reason;
      g_last_reason = block_reason;
      UpdatePanel();
      return;
   }

   if(SendMarketOrder(snapshot.signal, lots, snapshot.sl, snapshot.tp, snapshot.reason))
      g_last_trade_bar_time = iTime(g_symbol, InpSignalTimeframe, 0);

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
   snapshot.spread_points = CurrentSpreadPoints();
   snapshot.reason = "No clear setup";
}

bool BuildStrategySnapshot(StrategySnapshot &snapshot)
{
   ResetSnapshot(snapshot);

   int bars_needed = InpRangeLookbackBars + 20;
   if(bars_needed < 90)
      bars_needed = 90;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(g_symbol, InpSignalTimeframe, 0, bars_needed, rates) < bars_needed)
      return false;

   double ema_fast[], ema_slow[], ema_fast_higher[], ema_slow_higher[];
   double adx[], atr[], rsi[], bands_mid[], bands_upper[], bands_lower[];
   ArraySetAsSeries(ema_fast, true);
   ArraySetAsSeries(ema_slow, true);
   ArraySetAsSeries(ema_fast_higher, true);
   ArraySetAsSeries(ema_slow_higher, true);
   ArraySetAsSeries(adx, true);
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

   bool ema_up = ema_fast[1] > ema_slow[1] && ema_fast[1] > ema_fast[3] && ema_slow[1] >= ema_slow[3];
   bool ema_down = ema_fast[1] < ema_slow[1] && ema_fast[1] < ema_fast[3] && ema_slow[1] <= ema_slow[3];
   bool higher_up = ema_fast_higher[1] > ema_slow_higher[1] && ema_fast_higher[1] > ema_fast_higher[3];
   bool higher_down = ema_fast_higher[1] < ema_slow_higher[1] && ema_fast_higher[1] < ema_fast_higher[3];
   bool atr_active = atr[1] >= atr_average * InpMinAtrFactor;
   bool close_above_mid = rates[1].close > bands_mid[1];
   bool close_below_mid = rates[1].close < bands_mid[1];
   double ema_gap_atr = MathAbs(ema_fast[1] - ema_slow[1]) / MathMax(atr[1], g_point);

   if(adx[1] >= InpTrendAdxThreshold && atr_active && ema_up && higher_up && close_above_mid)
      snapshot.regime = REGIME_TREND_UP;
   else if(adx[1] >= InpTrendAdxThreshold && atr_active && ema_down && higher_down && close_below_mid)
      snapshot.regime = REGIME_TREND_DOWN;
   else if(adx[1] <= InpRangeAdxThreshold && ema_gap_atr <= InpRangeEmaGapAtr &&
           HasUsableRange(rates, atr[1]))
      snapshot.regime = REGIME_RANGE;
   else
      snapshot.regime = REGIME_UNKNOWN;

   ENUM_TRADE_SIGNAL signal = SIGNAL_NONE;
   string reason = "";

   if(snapshot.regime == REGIME_TREND_UP)
   {
      bool pullback = rates[1].low <= ema_fast[1] || rates[2].low <= ema_fast[2] || rates[1].low <= bands_mid[1];
      bool resumed = rates[1].close > ema_fast[1] && rates[1].close > rates[1].open;
      bool rsi_room = rsi[1] < InpRsiOverbought;
      if(pullback && resumed && rsi_room)
      {
         signal = SIGNAL_BUY;
         reason = "Trend buy: ADX strong, HTF up, pullback resumed";
      }
      else
      {
         reason = "Trend up, but no safe pullback entry";
      }
   }
   else if(snapshot.regime == REGIME_TREND_DOWN)
   {
      bool pullback = rates[1].high >= ema_fast[1] || rates[2].high >= ema_fast[2] || rates[1].high >= bands_mid[1];
      bool resumed = rates[1].close < ema_fast[1] && rates[1].close < rates[1].open;
      bool rsi_room = rsi[1] > InpRsiOversold;
      if(pullback && resumed && rsi_room)
      {
         signal = SIGNAL_SELL;
         reason = "Trend sell: ADX strong, HTF down, pullback resumed";
      }
      else
      {
         reason = "Trend down, but no safe pullback entry";
      }
   }
   else if(snapshot.regime == REGIME_RANGE)
   {
      bool near_lower = rates[1].low <= bands_lower[1] + atr[1] * 0.20 && rates[1].close > bands_lower[1];
      bool near_upper = rates[1].high >= bands_upper[1] - atr[1] * 0.20 && rates[1].close < bands_upper[1];
      bool rsi_turn_up = rsi[2] <= InpRsiOversold && rsi[1] > rsi[2];
      bool rsi_turn_down = rsi[2] >= InpRsiOverbought && rsi[1] < rsi[2];
      bool bullish_reject = IsBullishRejection(rates[1]);
      bool bearish_reject = IsBearishRejection(rates[1]);

      if(near_lower && rsi_turn_up && bullish_reject)
      {
         signal = SIGNAL_BUY;
         reason = "Range buy: lower band rejection with RSI turn";
      }
      else if(near_upper && rsi_turn_down && bearish_reject)
      {
         signal = SIGNAL_SELL;
         reason = "Range sell: upper band rejection with RSI turn";
      }
      else
      {
         reason = "Range regime, but price is not at a clean edge";
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
         snapshot.sl = MathMin(swing_sl, atr_sl);
         snapshot.tp = snapshot.entry + (snapshot.entry - snapshot.sl) * EffectiveTrendRewardRisk();
      }
      else
      {
         double swing_sl = HighestHigh(rates, 1, 10) + atr_value * 0.20;
         double atr_sl = snapshot.entry + atr_value * InpTrendAtrStopMultiplier;
         snapshot.sl = MathMax(swing_sl, atr_sl);
         snapshot.tp = snapshot.entry - (snapshot.sl - snapshot.entry) * EffectiveTrendRewardRisk();
      }
   }
   else if(snapshot.regime == REGIME_RANGE)
   {
      if(is_buy)
      {
         snapshot.sl = MathMin(rates[1].low - atr_value * InpRangeAtrStopBuffer,
                               band_lower - atr_value * 0.20);
         double rr_tp = snapshot.entry + (snapshot.entry - snapshot.sl) * InpRangeRewardRisk;
         snapshot.tp = MathMax(band_mid, rr_tp);
      }
      else
      {
         snapshot.sl = MathMax(rates[1].high + atr_value * InpRangeAtrStopBuffer,
                               band_upper + atr_value * 0.20);
         double rr_tp = snapshot.entry - (snapshot.sl - snapshot.entry) * InpRangeRewardRisk;
         snapshot.tp = MathMin(band_mid, rr_tp);
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

   if(lots <= 0.0)
   {
      reason = "Invalid lot size";
      return 0.0;
   }

   reason = "";
   return lots;
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
            g_daily_profit += HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
            g_daily_profit += HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
            g_daily_profit += HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
         }
      }
   }

   g_consecutive_losses = CalculateConsecutiveLosses();
}

int CalculateConsecutiveLosses()
{
   if(!HistorySelect(0, TimeCurrent()))
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

bool HasUsableRange(MqlRates &rates[], double atr_value)
{
   int lookback = MathMax(12, InpRangeLookbackBars);
   if(ArraySize(rates) <= lookback + 2 || atr_value <= 0.0)
      return false;

   double high = HighestHigh(rates, 1, lookback);
   double low = LowestLow(rates, 1, lookback);
   double width_atr = (high - low) / atr_value;

   return width_atr > 1.5 && width_atr <= InpRangeMaxWidthAtr;
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

void CreatePanel()
{
   DeletePanel();

   int x = InpPanelX;
   int y = InpPanelY;
   int width = 376;
   int height = 386;

   CreateRect("BG", x, y, width, height, C'18,24,33', C'64,78,96');
   CreateLabel("TITLE", x + 14, y + 10, "XAUUSD Regime EA", 11, clrWhite);
   CreateLabel("SUBTITLE", x + 14, y + 31, "Trend-following + range-reversal", 8, C'151,164,183');

   int row_y = y + 58;
   int gap = 19;
   CreateMetricRow(0, row_y + gap * 0, "Auto", "");
   CreateMetricRow(1, row_y + gap * 1, "Profile", "");
   CreateMetricRow(2, row_y + gap * 2, "Regime", "");
   CreateMetricRow(3, row_y + gap * 3, "Signal", "");
   CreateMetricRow(4, row_y + gap * 4, "Reason", "");
   CreateMetricRow(5, row_y + gap * 5, "Spread", "");
   CreateMetricRow(6, row_y + gap * 6, "ADX / RSI", "");
   CreateMetricRow(7, row_y + gap * 7, "ATR", "");
   CreateMetricRow(8, row_y + gap * 8, "Positions", "");
   CreateMetricRow(9, row_y + gap * 9, "Today P/L", "");
   CreateMetricRow(10, row_y + gap * 10, "Daily trades", "");
   CreateMetricRow(11, row_y + gap * 11, "Last action", "");

   CreateButton("BTN_SAFE", x + 14, y + 318, 104, 25, "Safe", C'35,134,90');
   CreateButton("BTN_STANDARD", x + 126, y + 318, 104, 25, "Standard", C'84,100,122');
   CreateButton("BTN_AGGRESSIVE", x + 238, y + 318, 122, 25, "Aggressive", C'194,120,3');
   CreateButton("BTN_AUTO", x + 14, y + 350, 168, 25, "Pause", C'37,99,235');
   CreateButton("BTN_CLOSE", x + 192, y + 350, 168, 25, "Close Positions", C'220,53,69');

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
   if(!InpShowPanel)
      return;

   StrategySnapshot snapshot;
   ResetSnapshot(snapshot);
   BuildStrategySnapshot(snapshot);

   SetMetricValue(0, g_auto_enabled ? "ON" : "PAUSED", g_auto_enabled ? C'74,222,128' : C'248,113,113');
   SetMetricValue(1, g_profile_name + " / risk " + DoubleToString(EffectiveRiskPercent(), 2) + "%", clrWhite);
   SetMetricValue(2, RegimeToString(snapshot.regime), RegimeColor(snapshot.regime));
   SetMetricValue(3, SignalToString(snapshot.signal), SignalColor(snapshot.signal));
   SetMetricValue(4, TrimForPanel(snapshot.reason, 33), C'226,232,240');
   SetMetricValue(5, DoubleToString(CurrentSpreadPoints(), 0) + " pts", CurrentSpreadPoints() <= InpMaxSpreadPoints ? clrWhite : C'248,113,113');
   SetMetricValue(6, DoubleToString(snapshot.adx, 1) + " / " + DoubleToString(snapshot.rsi, 1), clrWhite);
   SetMetricValue(7, DoubleToString(snapshot.atr, g_digits), clrWhite);
   SetMetricValue(8, IntegerToString(CountOpenPositions()) + " / " + IntegerToString(InpMaxOpenPositions), clrWhite);
   SetMetricValue(9, DoubleToString(g_daily_profit, 2), g_daily_profit >= 0.0 ? C'74,222,128' : C'248,113,113');
   SetMetricValue(10, IntegerToString(g_daily_trades) + " / " + IntegerToString(InpMaxTradesPerDay), clrWhite);
   SetMetricValue(11, TrimForPanel(g_last_trade_result, 33), C'226,232,240');

   string auto_button = PANEL_PREFIX + "BTN_AUTO";
   if(ObjectFind(0, auto_button) >= 0)
   {
      ObjectSetString(0, auto_button, OBJPROP_TEXT, g_auto_enabled ? "Pause" : "Start");
      ObjectSetInteger(0, auto_button, OBJPROP_BGCOLOR, g_auto_enabled ? C'37,99,235' : C'35,134,90');
   }
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
