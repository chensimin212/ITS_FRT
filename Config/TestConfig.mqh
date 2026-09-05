#property strict
#ifndef ITS_FRT_CONFIG_TESTCONFIG_MQH
#define ITS_FRT_CONFIG_TESTCONFIG_MQH

#include <Object.mqh>
#include "./BaseConfig.mqh"
#include "./FuncInputs.mqh"

//--------------------------------------------------------------------
// CTestConfig - EA 配置类（测试环境，ITS_FRT 精简版）
//--------------------------------------------------------------------
class CTestConfig : public CBaseConfig {
public:
    CTestConfig() {}
    ~CTestConfig() {}

protected:
    bool InitEnvironment() override;
    bool LoadFunction() override;
};

//--------------------------------------------------------------------
// 初始化环境
//--------------------------------------------------------------------
bool CTestConfig::InitEnvironment() override {
    _logger.Enable(true);
    _logger.SetModuleName("测试配置");
    _logger.SetLogLevel(LogLevel);
    return true;
}

//--------------------------------------------------------------------
// 加载功能配置（仅加载实际使用的参数）
//--------------------------------------------------------------------
bool CTestConfig::LoadFunction() override {
    // 风控管理
    FixedRiskEquity = InpFixedRiskEquity;
    MaxRiskPerTradePct = InpMaxRiskPerTradePct;
    MaxRiskPerDirectionPct = InpMaxRiskPerDirectionPct;
    CircuitBreakerDrawdownPct = InpCircuitBreakerDrawdownPct;
    MaxLotSize = InpMaxLotSize;
    MaxMarginUsagePct = InpMaxMarginUsagePct;
    MinMarginLevelPct = InpMinMarginLevelPct;

    // 订单执行
    SlippagePoints = InpSlippagePoints;

    // 定时清仓
    CloseBeforeMinutes = InpCloseBeforeMinutes;
    PauseBeforeMinutes = InpPauseBeforeMinutes;

    // 尾随止损
    TrailingLookbackBars = InpTrailingLookbackBars;
    TrailingProfitLockPct = InpTrailingProfitLockPct;
    TrailingProfitLockATR = InpTrailingProfitLockATR;
    TrailingMaxStopLossATR = InpTrailingMaxStopLossATR;

    // 交易周期（ITS_FRT 使用单周期）
    TradeTimeframe = PERIOD_M5;

    return true;
}

#endif
