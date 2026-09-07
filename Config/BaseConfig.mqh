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
    int SlippagePoints; // 执行:允许价格偏差点数(0=不允许偏差):要求[0,+∞)

    // 交易周期
    ENUM_TIMEFRAMES TradeTimeframe; // 周期:做单(兼公共市场状态与主循环门控)

    //====================================================================
    // 二、仓位管理
    //====================================================================

    // 尾随止损
    int TrailingLookbackBars;      // 结构:极值回看K线数
    double TrailingProfitLockPct;  // 锁盈:价格百分比(与ATR口径取较大值)
    double TrailingProfitLockATR;  // 锁盈:ATR倍数(与百分比口径取较大值)
    double TrailingMaxStopLossATR; // 边界:最大止损距离ATR倍数

    // 定时清仓
    int CloseBeforeMinutes; // 窗口:交易时段结束前清仓分钟数
    int PauseBeforeMinutes; // 窗口:清仓前停止开仓分钟数

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

    // 交易周期：PERIOD_CURRENT(0) 会被解析为当前图表周期，此处仅要求能解析出正的周期长度
    if (PeriodSeconds(TradeTimeframe) <= 0)
        return _logger.AlertError4Boolean("做单周期取值非法:无法解析周期长度");

    //================================================================
    // 二、仓位管理
    //================================================================

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
