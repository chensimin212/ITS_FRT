#property strict
#ifndef ITS_FRT_STATE_MARKETSTATE_MQH
#define ITS_FRT_STATE_MARKETSTATE_MQH

#include <Object.mqh>
#include "../Core/Logger.mqh"
#include "../Config/BaseConfig.mqh"
#include "./SymbolState.mqh"

//--------------------------------------------------------------------
// CMarketState - 市场状态（ITS_FRT 简化版，无三周期分析）
//--------------------------------------------------------------------
class CMarketState : public CObject {
private:
    CLogger _logger;
    CBaseConfig *_config;
    CSymbolState *_symbolState;

public:
    double TradeATR;           // 交易周期 ATR，供尾随止损读取；当前 Refresh() 恒置 0（未实现计算）
    datetime DaySessionClose;  // 当日收盘时间

public:
    CMarketState();
    ~CMarketState() {}

    bool Init(CBaseConfig *config, CSymbolState *symbolState);
    bool Refresh();

    // 辅助方法
    double LowestPriceOn(ENUM_TIMEFRAMES timeframe, int lookbackBars, int shift = 0);
    double HighestPriceOn(ENUM_TIMEFRAMES timeframe, int lookbackBars, int shift = 0);
};

//--------------------------------------------------------------------
// 构造函数
//--------------------------------------------------------------------
CMarketState::CMarketState() {
    TradeATR = 0.0;
    DaySessionClose = 0;
}

//--------------------------------------------------------------------
// 初始化
//--------------------------------------------------------------------
bool CMarketState::Init(CBaseConfig *config, CSymbolState *symbolState) {
    if (config == NULL || symbolState == NULL) {
        return false;
    }

    _config = config;
    _symbolState = symbolState;

    _logger.Enable(true);
    _logger.SetModuleName("市场状态");
    _logger.SetLogLevel(_config.LogLevel);
    _logger.LogInfo("市场状态初始化（ITS_FRT 简化版）");

    return true;
}

//--------------------------------------------------------------------
// 刷新市场状态
//--------------------------------------------------------------------
bool CMarketState::Refresh() {
    // 计算当日收盘时间
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    dt.hour = 23;
    dt.min = 59;
    dt.sec = 59;
    DaySessionClose = StructToTime(dt);

    // ITS_FRT 暂不计算 ATR
    TradeATR = 0.0;

    return true;
}

//--------------------------------------------------------------------
// 获取指定周期的最低价（简化实现）
//--------------------------------------------------------------------
double CMarketState::LowestPriceOn(ENUM_TIMEFRAMES timeframe, int lookbackBars, int shift = 0) {
    if (lookbackBars <= 0) return 0.0;

    double lowArray[];
    ArraySetAsSeries(lowArray, true);
    int copied = CopyLow(_config.Symbol, timeframe, shift, lookbackBars, lowArray);
    if (copied <= 0) return 0.0;

    return lowArray[ArrayMinimum(lowArray, 0, copied)];
}

//--------------------------------------------------------------------
// 获取指定周期的最高价（简化实现）
//--------------------------------------------------------------------
double CMarketState::HighestPriceOn(ENUM_TIMEFRAMES timeframe, int lookbackBars, int shift = 0) {
    if (lookbackBars <= 0) return 0.0;

    double highArray[];
    ArraySetAsSeries(highArray, true);
    int copied = CopyHigh(_config.Symbol, timeframe, shift, lookbackBars, highArray);
    if (copied <= 0) return 0.0;

    return highArray[ArrayMaximum(highArray, 0, copied)];
}

#endif
