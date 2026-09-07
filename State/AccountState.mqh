#ifndef CONTROLLED_MARTINGALE_STATE_ACCOUNTSTATE_MQH
#define CONTROLLED_MARTINGALE_STATE_ACCOUNTSTATE_MQH

#property strict

#include <Object.mqh>
#include "../Config/BaseConfig.mqh"
#include "../Core/Logger.mqh"

//--------------------------------------------------------------------
// CAccountState - 账号信息状态
//--------------------------------------------------------------------
class CAccountState : public CObject {
private:
    CLogger _logger;      // 账户状态刷新与启动保护诊断日志器
    CBaseConfig *_config; // 账户许可、最低净值和回撤限制配置
    bool _initialized;    // 是否已初始化

public:
    double Balance;     // 结余
    double Equity;      // 净值
    double Margin;      // 已用保证金
    double FreeMargin;  // 可用保证金
    double MarginLevel; // 保证金比例
    double EquityInit;  // 初始净值
    double EquityPeak;  // 净值峰值
    double Drawdown;    // 回撤
    double DrawdownPct; // 回撤百分比

public:
    CAccountState();  // 构造账户状态并清空账户事实
    ~CAccountState(); // 析构账户状态对象

    bool Refresh();                 // 刷新
    bool Init(CBaseConfig *config); // 初始化

private:
    bool CheckStartupGuards(); // 启动前置守卫：持仓模式与固定模式净值下限；不满足时告警并返回 false
    double CalcDrawdownPct();  // 计算回撤百分比
};

//--------------------------------------------------------------------
// 构造函数
//--------------------------------------------------------------------
CAccountState::CAccountState() {
    _config = NULL;
    _initialized = false;
}

//--------------------------------------------------------------------
// 析构函数
//--------------------------------------------------------------------
CAccountState::~CAccountState() {
}

//--------------------------------------------------------------------
// 初始化
//--------------------------------------------------------------------
bool CAccountState::Init(CBaseConfig *config) {
    _config = config;

    // 日志设置：
    _logger.Enable(true);
    _logger.SetModuleName("账号状态");
    _logger.SetLogLevel(_config.LogLevel);

    // 防止切换时间周期时，重新初始化
    if (_initialized) return true;

    // 账号信息：
    Balance = AccountInfoDouble(ACCOUNT_BALANCE);          // 结余
    Equity = AccountInfoDouble(ACCOUNT_EQUITY);            // 净值
    Margin = AccountInfoDouble(ACCOUNT_MARGIN);            // 已用保证金
    FreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);   // 可用保证金
    MarginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL); // 保证金比例
    EquityInit = Equity;                                   // 初始净值

    // 启动前置守卫：不满足直接拒绝初始化
    if (!CheckStartupGuards()) return false;

    EquityPeak = MathMax(Equity, _config.FixedRiskEquity); // 净值峰值
    Drawdown = MathMax(EquityPeak - Equity, 0.0);          // 回撤
    DrawdownPct = CalcDrawdownPct();                       // 回撤百分比

    // 初始化成功：
    _initialized = true;
    return true;
}

//--------------------------------------------------------------------
// 启动前置守卫：账户持仓模式必须为对冲；固定模式启动净值不得低于
//--------------------------------------------------------------------
bool CAccountState::CheckStartupGuards() {
    // 固定风险净值的下限比例。任一不满足即告警并返回 false 拒绝初始化
    // 账户持仓模式守卫：非对冲模式下反向首仓会减仓或反转现有仓位，直接拒绝启动
    ENUM_ACCOUNT_MARGIN_MODE marginMode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
    if (marginMode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) {
        string marginModeName = EnumToString(marginMode);
        return _logger.AlertError4Boolean(StringFormat("账户持仓模式必须为对冲模式，当前=%s；已拒绝启动以避免反向首仓减仓或反转现有仓位", marginModeName));
    }

    // 固定模式仅允许启动净值比固定风险净值低5%
    double fixedPeakFloor = _config.FixedRiskEquity * FIXED_MODE_MIN_INITIAL_EQUITY_RATIO;
    if (EquityInit < fixedPeakFloor) {
        return _logger.AlertError4Boolean(StringFormat("启动净值%.2f低于固定风险净值%.2f的95%%", EquityInit, _config.FixedRiskEquity));
    }
    return true;
}

//--------------------------------------------------------------------
// 刷新
//--------------------------------------------------------------------
bool CAccountState::Refresh() {
    Balance = AccountInfoDouble(ACCOUNT_BALANCE);          // 结余
    Equity = AccountInfoDouble(ACCOUNT_EQUITY);            // 净值
    Margin = AccountInfoDouble(ACCOUNT_MARGIN);            // 已用保证金
    FreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);   // 可用保证金
    MarginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL); // 保证金比例
    EquityPeak = MathMax(EquityPeak, Equity);              // 净值峰值
    Drawdown = MathMax(EquityPeak - Equity, 0);            // 回撤
    DrawdownPct = CalcDrawdownPct();                       // 回撤百分比
    return true;
}

//--------------------------------------------------------------------
// 计算回撤百分比：动态模式按净值峰值，固定模式按固定风险净值
//--------------------------------------------------------------------
double CAccountState::CalcDrawdownPct() {
    double equityBasis = _config.FixedRiskEquity;
    return (equityBasis > 0 ? (Drawdown / equityBasis * 100) : 0);
}

#endif
