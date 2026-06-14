// MT5 历史数据批量导出脚本
// 将此文件放到 MT5 的 MQL5/Scripts/ 目录下，然后在 MT5 中运行
// 路径: MQL5/Scripts/ExportXAUUSD_M15.mq5

#property script_show_inputs

input string   InpSymbol = "XAUUSD";
input int      InpTimeframe = PERIOD_M15;   // 目标周期
input datetime InpFromDate = D'2023.01.01';
input datetime InpToDate   = D'2026.06.15';
input string   InpOutputFile = "XAUUSD_M15.csv";

void OnStart()
{
   string symbol = InpSymbol;
   ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)InpTimeframe;

   // 确保品种在行情列表
   if(!SymbolSelect(symbol, true))
   {
      Print("错误: 无法选择品种 ", symbol);
      return;
   }

   // 打开文件
   string filename = InpOutputFile;
   int handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
   {
      Print("错误: 无法创建文件 ", filename);
      return;
   }

   // 写入 CSV 头部
   FileWrite(handle, "<DATE>,<TIME>,<OPEN>,<HIGH>,<LOW>,<CLOSE>,<TICKVOL>,<VOL>,<SPREAD>");

   // 获取历史数据
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   datetime from = InpFromDate;
   datetime to = InpToDate;
   int copied = 0;
   int total = 0;

   while(from < to)
   {
      int count = CopyRates(symbol, tf, from, 20000, rates);
      if(count <= 0)
      {
         Print("CopyRates 失败: ", GetLastError(), " 日期=", TimeToString(from));
         break;
      }

      copied += count;

      for(int i = count - 1; i >= 0; i--)
      {
         string date_str = TimeToString(rates[i].time, TIME_DATE);
         string time_str = TimeToString(rates[i].time, TIME_MINUTES);
         StringReplace(date_str, ".", ".");

         FileWrite(handle,
            date_str,
            time_str,
            DoubleToString(rates[i].open, _Digits),
            DoubleToString(rates[i].high, _Digits),
            DoubleToString(rates[i].low, _Digits),
            DoubleToString(rates[i].close, _Digits),
            IntegerToString(rates[i].tick_volume),
            "0",
            IntegerToString(rates[i].spread)
         );
         total++;
      }

      // 推进时间
      from = rates[0].time + PeriodSeconds(tf);
   }

   FileClose(handle);
   Print("导出完成! 文件: ", filename, " 行数: ", total);
}
