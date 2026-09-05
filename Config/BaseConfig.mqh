#property strict
#ifndef CONTROLLED_MARTINGALE_CONFIG_BASECONFIG_MQH
#define CONTROLLED_MARTINGALE_CONFIG_BASECONFIG_MQH

#include <Object.mqh>
#include "../Core/Enums.mqh"
#include "./SysInputs.mqh"
#include "../Core/Consts.mqh"
#include "../Core/Logger.mqh"

//--------------------------------------------------------------------
// CBaseConfig - EA 配置类
//--------------------------------------------------------------------
class CBaseConfig : public CObject
{
protected:
    CLogger _logger; // 配置模块日志器（子类初始化环境时启用）

public:
    // 公开业务属性：State、Filter、Manager 与 Api 统一读取
    string Symbol; // 交易品种（Init 时取自 _Symbol）

    //====================================================================
    // 一、基础配置
    //====================================================================

    // 系统设置
    long MagicNumber;        // 标识:EA魔术号(唯一):要求>0
    int TickPoints;          // Tick:触发点数(0=禁用):要求[0,+∞)
    double CommissionPerLot; // 成本:每手双边总佣金:要求[0,+∞)
    E_LOG_LEVEL LogLevel;    // 日志:输出等级

    // 风控管理
    double FixedRiskEquity;           // 基准:风险预算基准净值(账户货币):要求(0,+∞)
    double MaxRiskPerTradePct;        // 限额:单笔最大风险率(%):要求(0,100]
    double MaxRiskPerDirectionPct;    // 限额:单向最大风险率(%,0=不限制):要求[0,100]
    double CircuitBreakerDrawdownPct; // 熔断:净值回撤率(%):要求(0,100]
    double MaxLotSize;                // 限额:单笔订单最大手数:要求(0,+∞)
    double MaxMarginUsagePct;         // 限额:单笔最大保证金使用率(%):要求(0,100]
    double MinMarginLevelPct;         // 限额:开仓后最低保证金比例(%,0=不限制):要求[0,+∞)

    // 交易执行
    int SlippagePoints;  // 执行:允许价格偏差点数(0=不允许偏差):要求[0,+∞)
    int MaxSpreadPoints; // 执行:允许最大点差(点,0=不限制):要求[0,+∞)

    //====================================================================
    // 二、市场分析配置（按三周期组织）
    //   三周期字段完全同构；窗口类参数按各周期自然节奏分别取值。
    //   各周期的 Timeframe 置于该组首位，与 FuncInputs 的分组一致。
    //====================================================================

    // 宏观周期分析
    ENUM_TIMEFRAMES MacroTimeframe; // 周期:宏观(日线级别)
    int MacroSwingStrength;         // 摆动点:分形左右确认K线数
    double MacroSwingMinATR;        // 摆动点:相邻异类最小ATR间距
    int MacroSwingLookbackBars;     // 摆动点:搜索历史K线数
    int MacroATRPeriod;             // 指标:ATR周期
    int MacroFastEMAPeriod;         // 指标:快速EMA周期
    int MacroSlowEMAPeriod;         // 指标:慢速EMA周期
    int MacroADXPeriod;             // 指标:ADX周期
    int MacroRSIPeriod;             // 指标:RSI周期
    int MacroBollPeriod;            // 指标:布林周期
    double MacroBollDeviation;      // 指标:布林偏差
    int MacroSlopeLookbackBars;     // 窗口:斜率回看K线数
    int MacroBaselineBars;          // 窗口:基线K线数
    double MacroMinTrendADX;        // 判定:最低趋势ADX门槛

    // 中观周期分析
    ENUM_TIMEFRAMES MiddleTimeframe; // 周期:中观(小时级别)
    int MiddleSwingStrength;         // 摆动点:分形左右确认K线数
    double MiddleSwingMinATR;        // 摆动点:相邻异类最小ATR间距
    int MiddleSwingLookbackBars;     // 摆动点:搜索历史K线数
    int MiddleATRPeriod;             // 指标:ATR周期
    int MiddleFastEMAPeriod;         // 指标:快速EMA周期
    int MiddleSlowEMAPeriod;         // 指标:慢速EMA周期
    int MiddleADXPeriod;             // 指标:ADX周期
    int MiddleRSIPeriod;             // 指标:RSI周期
    int MiddleBollPeriod;            // 指标:布林周期
    double MiddleBollDeviation;      // 指标:布林偏差
    int MiddleSlopeLookbackBars;     // 窗口:斜率回看K线数
    int MiddleBaselineBars;          // 窗口:基线K线数
    double MiddleMinTrendADX;        // 判定:最低趋势ADX门槛

    // 做单周期分析
    ENUM_TIMEFRAMES TradeTimeframe; // 周期:做单(兼公共市场状态与主循环门控)
    int TradeSwingStrength;         // 摆动点:分形左右确认K线数
    double TradeSwingMinATR;        // 摆动点:相邻异类最小ATR间距
    int TradeSwingLookbackBars;     // 摆动点:搜索历史K线数
    int TradeATRPeriod;             // 指标:ATR周期(兼公共市场状态ATR)
    int TradeFastEMAPeriod;         // 指标:快速EMA周期
    int TradeSlowEMAPeriod;         // 指标:慢速EMA周期
    int TradeADXPeriod;             // 指标:ADX周期
    int TradeRSIPeriod;             // 指标:RSI周期
    int TradeBollPeriod;            // 指标:布林周期
    double TradeBollDeviation;      // 指标:布林偏差
    int TradeSlopeLookbackBars;     // 窗口:斜率回看K线数
    int TradeBaselineBars;          // 窗口:基线K线数
    double TradeMinTrendADX;        // 判定:最低趋势ADX门槛

    // 市场状态判定（三周期共用）
    double MarketTrendChangeLevel; // 判定:ADX变化量的趋势加速/衰竭阈值
    double MarketNearEMAATR;       // 判定:视为贴近快EMA的ATR倍数(三周期共用)
    double MarketRSIMidline;       // 判定:RSI中线(动量恢复方向分界)

    // 波动率分类（三周期共用）
    int VolatilityShortWindowBars; // 窗口:短期分位统计K线数
    int VolatilityLongWindowBars;  // 窗口:长期分位统计K线数

    // 高级分析参数：方向评分权重
    double ScoreStructureWeight;
    double ScoreEMAWeight;
    double ScoreDIWeight;
    double ScoreADXWeight;
    double ResonanceAlignMinStrength;

    // 高级分析参数：波动分类器阈值
    double VolatilityPercentileSpike;
    double VolatilityPercentileExpansion;
    double VolatilityPercentileLow;
    double VolatilityPercentileShockBar;
    double VolatilityFallbackShockBar;
    double VolatilityFallbackShockATR;
    double VolatilityFallbackExpansionATR;
    double VolatilityFallbackLow;
    int VolatilityMinSampleSize;
    double VolatilityMonotonicityFactor;

    // 高级分析参数：触发形态评分
    double TriggerDirectionWeight;
    double TriggerPullbackRecovery;
    double TriggerBreakoutContinuation;
    double TriggerRangeReversal;
    double TriggerFalseBreakRecovery;
    double ForwardSpaceMinATR;
    double ForwardSpaceBreakoutRatio;

    //====================================================================
    // 三、仓位管理
    //====================================================================

    // 开仓止损
    int StopLookbackBars; // 结构:极值回看K线数
    double StopBufferATR; // 结构:极值外缓冲ATR倍数
    double StopMinATR;    // 边界:最小止损ATR倍数
    double StopMaxATR;    // 边界:最大止损ATR倍数

    // 尾随止损
    int TrailingLookbackBars;      // 结构:极值回看K线数
    double TrailingProfitLockPct;  // 锁盈:价格百分比(与ATR口径取较大值)
    double TrailingProfitLockATR;  // 锁盈:ATR倍数(与百分比口径取较大值)
    double TrailingMaxStopLossATR; // 边界:最大止损距离ATR倍数

    // 定时清仓
    int CloseBeforeMinutes; // 窗口:交易时段结束前清仓分钟数
    int PauseBeforeMinutes; // 窗口:清仓前停止开仓分钟数

    //====================================================================
    // 四、市场开仓信号 (OpeningSignal)
    //====================================================================

public:
    //--------------------------------------------------------------------
    // 构造基础配置对象并由字段默认值建立初始配置状态。
    //--------------------------------------------------------------------
    CBaseConfig()
    {
    }

    //--------------------------------------------------------------------
    // 析构基础配置对象；不持有需要手动释放的外部资源。
    //--------------------------------------------------------------------
    ~CBaseConfig()
    {
    }

    bool Init(); // 初始化

protected:
    virtual bool InitEnvironment() = NULL; // 初始化环境
    virtual bool LoadFunction() = NULL;    // 加载功能配置

private:
    bool LoadSystem();  // 加载系统配置
    bool CheckInputs(); // 检查所有配置
};

//--------------------------------------------------------------------
// 初始化
//--------------------------------------------------------------------
bool CBaseConfig::Init()
{
    Symbol = _Symbol;

    if (!LoadSystem())
        return false;
    if (!InitEnvironment())
        return false;
    if (!LoadFunction())
        return false;
    if (!CheckInputs())
        return false;

    return true;
}

//--------------------------------------------------------------------
// 加载系统配置
//--------------------------------------------------------------------
bool CBaseConfig::LoadSystem()
{
    MagicNumber = InpMagicNumber;
    CommissionPerLot = InpCommissionPerLot;
    TickPoints = InpTickPoints;
    LogLevel = InpLogLevel;
    return true;
}

//--------------------------------------------------------------------
// 检查所有配置
//--------------------------------------------------------------------
bool CBaseConfig::CheckInputs()
{
    //================================================================
    // 一、基础配置
    //================================================================

    // 系统设置：
    if (MagicNumber <= 0)
        return _logger.AlertError4Boolean("EA魔术号【要求唯一】:要求>0");
    if (CommissionPerLot < 0)
        return _logger.AlertError4Boolean("每手双边总佣金:要求[0,+∞)");
    if (TickPoints < 0)
        return _logger.AlertError4Boolean("Tick触发点数:要求[0,+∞)");

    // 风控管理：
    if (FixedRiskEquity <= 0)
        return _logger.AlertError4Boolean("风险预算基准净值(账户货币):要求(0,+∞)");
    if (MaxRiskPerTradePct <= 0 || MaxRiskPerTradePct > 100)
        return _logger.AlertError4Boolean("单笔最大风险率(%):要求(0,100]");
    if (MaxRiskPerDirectionPct < 0 || MaxRiskPerDirectionPct > 100)
        return _logger.AlertError4Boolean("单向最大风险率(%):要求[0,100]");
    if (CircuitBreakerDrawdownPct <= 0 || CircuitBreakerDrawdownPct > 100)
        return _logger.AlertError4Boolean("熔断净值回撤率(%):要求(0,100]");
    if (MaxLotSize <= 0)
        return _logger.AlertError4Boolean("单笔订单最大手数:要求(0,+∞)");
    if (MaxMarginUsagePct <= 0 || MaxMarginUsagePct > 100)
        return _logger.AlertError4Boolean("单笔最大保证金使用率(%):要求(0,100]");
    if (MinMarginLevelPct < 0)
        return _logger.AlertError4Boolean("开仓后最低保证金比例(%):要求[0,+∞)");

    // 交易执行：
    if (SlippagePoints < 0)
        return _logger.AlertError4Boolean("允许价格偏差点数:要求[0,+∞)");
    if (MaxSpreadPoints < 0)
        return _logger.AlertError4Boolean("允许最大点差(点):要求[0,+∞)");

    //================================================================
    // 二、市场分析配置
    //   三周期字段同构，故同类项按「宏观/中观/做单」横向合并校验，
    //   与 FuncInputs 的纵向分组互为转置，便于一眼看出三周期口径是否一致。
    //================================================================

    // 三周期周期序：必须严格满足 宏观 > 中观 > 做单，否则三周期共振语义颠倒
    //   （"宏观"若比"做单"周期更短，Align 投票与共振分档表达的含义与命名相反）。
    //   PERIOD_CURRENT(0) 会被解析为当前图表周期，可能与其他周期取值相等，一并由本检查拦下。
    int macroSeconds = PeriodSeconds(MacroTimeframe);
    int middleSeconds = PeriodSeconds(MiddleTimeframe);
    int tradeSeconds = PeriodSeconds(TradeTimeframe);
    if (macroSeconds <= 0 || middleSeconds <= 0 || tradeSeconds <= 0)
        return _logger.AlertError4Boolean("三周期取值非法:无法解析周期长度");
    if (macroSeconds <= middleSeconds)
        return _logger.AlertError4Boolean("宏观周期必须长于中观周期");
    if (middleSeconds <= tradeSeconds)
        return _logger.AlertError4Boolean("中观周期必须长于做单周期");

    // 摆动点：回看窗口须大于 CSwingPointDetector 的下限 2*strength+2
    if (MacroSwingStrength < 1 || MacroSwingStrength > 5)
        return _logger.AlertError4Boolean("宏观摆动点分形强度:要求[1,5]");
    if (MiddleSwingStrength < 1 || MiddleSwingStrength > 5)
        return _logger.AlertError4Boolean("中观摆动点分形强度:要求[1,5]");
    if (TradeSwingStrength < 1 || TradeSwingStrength > 5)
        return _logger.AlertError4Boolean("做单摆动点分形强度:要求[1,5]");
    if (MacroSwingMinATR <= 0 || MiddleSwingMinATR <= 0 || TradeSwingMinATR <= 0)
        return _logger.AlertError4Boolean("摆动点最小ATR间距:要求(0,+∞)");
    if (MacroSwingLookbackBars < 20 || MacroSwingLookbackBars > 500 || MacroSwingLookbackBars <= 2 * MacroSwingStrength + 2)
        return _logger.AlertError4Boolean("宏观摆动点回看K线数:要求[20,500]且>2*强度+2");
    if (MiddleSwingLookbackBars < 20 || MiddleSwingLookbackBars > 500 || MiddleSwingLookbackBars <= 2 * MiddleSwingStrength + 2)
        return _logger.AlertError4Boolean("中观摆动点回看K线数:要求[20,500]且>2*强度+2");
    if (TradeSwingLookbackBars < 20 || TradeSwingLookbackBars > 500 || TradeSwingLookbackBars <= 2 * TradeSwingStrength + 2)
        return _logger.AlertError4Boolean("做单摆动点回看K线数:要求[20,500]且>2*强度+2");

    // 三周期指标周期：
    if (MacroATRPeriod <= 0 || MiddleATRPeriod <= 0 || TradeATRPeriod <= 0)
        return _logger.AlertError4Boolean("三周期ATR周期:要求(0,+∞)");
    if (MacroADXPeriod <= 0 || MiddleADXPeriod <= 0 || TradeADXPeriod <= 0)
        return _logger.AlertError4Boolean("三周期ADX周期:要求(0,+∞)");
    if (MacroRSIPeriod <= 0 || MiddleRSIPeriod <= 0 || TradeRSIPeriod <= 0)
        return _logger.AlertError4Boolean("三周期RSI周期:要求(0,+∞)");
    if (MacroBollPeriod <= 0 || MiddleBollPeriod <= 0 || TradeBollPeriod <= 0)
        return _logger.AlertError4Boolean("三周期布林周期:要求(0,+∞)");
    if (MacroBollDeviation <= 0 || MiddleBollDeviation <= 0 || TradeBollDeviation <= 0)
        return _logger.AlertError4Boolean("三周期布林偏差:要求(0,+∞)");
    if (MacroFastEMAPeriod <= 0 || MacroSlowEMAPeriod <= MacroFastEMAPeriod)
        return _logger.AlertError4Boolean("宏观EMA周期:要求快线>0且慢线>快线");
    if (MiddleFastEMAPeriod <= 0 || MiddleSlowEMAPeriod <= MiddleFastEMAPeriod)
        return _logger.AlertError4Boolean("中观EMA周期:要求快线>0且慢线>快线");
    if (TradeFastEMAPeriod <= 0 || TradeSlowEMAPeriod <= TradeFastEMAPeriod)
        return _logger.AlertError4Boolean("做单EMA周期:要求快线>0且慢线>快线");

    // 三周期斜率与基线窗口：基线须大于斜率窗口，否则比率与变化量口径不可比
    if (MacroSlopeLookbackBars < 1 || MacroSlopeLookbackBars > 100)
        return _logger.AlertError4Boolean("宏观斜率回看K线数:要求[1,100]");
    if (MiddleSlopeLookbackBars < 1 || MiddleSlopeLookbackBars > 100)
        return _logger.AlertError4Boolean("中观斜率回看K线数:要求[1,100]");
    if (TradeSlopeLookbackBars < 1 || TradeSlopeLookbackBars > 100)
        return _logger.AlertError4Boolean("做单斜率回看K线数:要求[1,100]");
    if (MacroBaselineBars < 20 || MacroBaselineBars > 500 || MacroBaselineBars <= MacroSlopeLookbackBars)
        return _logger.AlertError4Boolean("宏观基线窗口K线数:要求[20,500]且>斜率窗口");
    if (MiddleBaselineBars < 20 || MiddleBaselineBars > 500 || MiddleBaselineBars <= MiddleSlopeLookbackBars)
        return _logger.AlertError4Boolean("中观基线窗口K线数:要求[20,500]且>斜率窗口");
    if (TradeBaselineBars < 20 || TradeBaselineBars > 500 || TradeBaselineBars <= TradeSlopeLookbackBars)
        return _logger.AlertError4Boolean("做单基线窗口K线数:要求[20,500]且>斜率窗口");

    // 市场状态判定：
    if (MacroMinTrendADX <= 0 || MacroMinTrendADX > 100)
        return _logger.AlertError4Boolean("宏观最低趋势ADX门槛:要求(0,100]");
    if (MiddleMinTrendADX <= 0 || MiddleMinTrendADX > 100)
        return _logger.AlertError4Boolean("中观最低趋势ADX门槛:要求(0,100]");
    if (TradeMinTrendADX <= 0 || TradeMinTrendADX > 100)
        return _logger.AlertError4Boolean("做单最低趋势ADX门槛:要求(0,100]");
    if (MarketTrendChangeLevel <= 0)
        return _logger.AlertError4Boolean("趋势变化检测阈值:要求(0,+∞)");
    if (MarketNearEMAATR < 0)
        return _logger.AlertError4Boolean("均线附近ATR倍数:要求[0,+∞)");
    if (MarketRSIMidline <= 0 || MarketRSIMidline >= 100)
        return _logger.AlertError4Boolean("RSI中线值:要求(0,100)");

    // 波动率分类：
    if (VolatilityShortWindowBars < 10 || VolatilityShortWindowBars > 100)
        return _logger.AlertError4Boolean("波动短窗口K线数:要求[10,100]");
    if (VolatilityLongWindowBars < 50 || VolatilityLongWindowBars > 500)
        return _logger.AlertError4Boolean("波动长窗口K线数:要求[50,500]");
    if (VolatilityLongWindowBars <= VolatilityShortWindowBars)
        return _logger.AlertError4Boolean("波动长窗口须大于短窗口");

    //================================================================
    // 三、仓位管理
    //================================================================

    // 开仓止损：
    if (StopLookbackBars <= 0 || StopBufferATR < 0 || StopMinATR <= 0 || StopMaxATR < StopMinATR)
        return _logger.AlertError4Boolean("开仓止损参数非法");

    // 尾随止损：
    if (TrailingLookbackBars < 1)
        return _logger.AlertError4Boolean("尾随极值回看K线数:要求[1,+∞)");
    if (TrailingProfitLockPct < 0 || TrailingProfitLockPct > 100)
        return _logger.AlertError4Boolean("尾随锁盈当前价格百分比(%):要求[0,100]");
    if (TrailingProfitLockATR < 0)
        return _logger.AlertError4Boolean("尾随锁盈公共ATR倍数:要求[0,+∞)");
    if (TrailingMaxStopLossATR <= 0)
        return _logger.AlertError4Boolean("尾随最大止损距离ATR倍数:要求(0,+∞)");

    // 定时清仓：
    if (CloseBeforeMinutes < 1 || CloseBeforeMinutes >= 1440)
        return _logger.AlertError4Boolean("收盘前清仓提前量(分钟):要求[1,1440)");
    if (PauseBeforeMinutes < 0 || PauseBeforeMinutes >= 1440)
        return _logger.AlertError4Boolean("清仓前暂停提前量(分钟):要求[0,1440)");

    return true;
}

#endif
