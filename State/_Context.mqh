#ifndef CONTROLLED_MARTINGALE_STATE_CONTEXT_MQH
#define CONTROLLED_MARTINGALE_STATE_CONTEXT_MQH

#property strict

#include <Object.mqh>
#include "../Config/BaseConfig.mqh"
#include "../Core/Enums.mqh"
#include "../Core/Logger.mqh"
#include "SymbolState.mqh"
#include "AccountState.mqh"
#include "PositionState.mqh"
#include "MarketState.mqh"
#include "TradingState.mqh"

//--------------------------------------------------------------------
// CContext - 运行期共享上下文
//--------------------------------------------------------------------
class CContext : public CObject {
private:
    CLogger _logger; // 上下文初始化与刷新失败诊断日志器

public:
    CBaseConfig *Config;          // 由 EA 注入并供所有状态与业务模块共享的配置对象
    CSymbolState SymbolState;     // 品种状态
    CAccountState AccountState;   // 账号状态
    CPositionState PositionState; // 持仓状态
    CMarketState MarketState;     // 市场状态（三周期原子快照 / 兼容ATR与极值 / 交易时段收盘时刻）
    CTradingState TradingState;   // 交易状态（写侧 PauseEntry/ResumeEntry/Liquidating/Terminate）

public:
    CContext();  // 构造共享上下文并清空配置引用
    ~CContext(); // 析构共享上下文聚合对象

    bool Init(CBaseConfig *config);    // 初始化
    bool Refresh();                    // 刷新完整状态
    bool RefreshAfterPositionChange(); // 仓位变化后刷新账户与持仓状态
};

//--------------------------------------------------------------------
// 构造函数
//--------------------------------------------------------------------
CContext::CContext() {
    Config = NULL;
}

//--------------------------------------------------------------------
// 析构函数
//--------------------------------------------------------------------
CContext::~CContext() {
}

//--------------------------------------------------------------------
// 初始化
//--------------------------------------------------------------------
bool CContext::Init(CBaseConfig *config) {
    Config = config;
    if (!SymbolState.Init(config)) return false;
    if (!AccountState.Init(config)) return false;
    if (!PositionState.Init(config)) return false;
    if (!MarketState.Init(config, &SymbolState)) return false;
    if (!TradingState.Init(config)) return false;

    _logger.Enable(true);
    _logger.SetModuleName("上下文");
    _logger.SetLogLevel(config.LogLevel);
    return true;
}

//--------------------------------------------------------------------
// 刷新完整状态：刷新失败时暂停开仓并记录日志，刷新成功时解除刷新失败导致的无限期暂停
//--------------------------------------------------------------------
bool CContext::Refresh() {
    // 仅解除已到期的定时暂停
    TradingState.ResumeEntry(false);
    TradingState.PrintStatusLog();

    if (!AccountState.Refresh()) {
        TradingState.PauseEntry("刷新账号状态失败，暂停开仓", 0);
        return _logger.LogError4Boolean("刷新账号状态失败！");
    }
    if (!SymbolState.Refresh()) {
        TradingState.PauseEntry("刷新品种状态失败，暂停开仓", 0);
        return _logger.LogError4Boolean("刷新交易品种失败！");
    }
    if (!PositionState.Refresh()) {
        TradingState.PauseEntry("刷新持仓状态失败，暂停开仓", 0);
        return _logger.LogError4Boolean("刷新持仓状态失败！");
    }
    if (!MarketState.Refresh()) {
        TradingState.PauseEntry("刷新市场状态失败，暂停开仓", 0);
        return _logger.LogError4Boolean("刷新市场状态失败！");
    }

    // 全部刷新成功，解除刷新失败导致的无限期暂停；定时暂停与清仓、终止不受影响
    if (TradingState.IsPausedIndefinitely()) {
        TradingState.ResumeEntry(true);
    }

    return true;
}

//--------------------------------------------------------------------
// 仓位变化后刷新账户与持仓状态，供同一轮后续管理器读取最新风险与仓位
//   刷新失败的暂停同样不设恢复时间，由下一轮 Refresh() 成功后解除
//--------------------------------------------------------------------
bool CContext::RefreshAfterPositionChange() {
    if (!AccountState.Refresh()) {
        TradingState.PauseEntry("仓位变化后刷新账号状态失败，暂停开仓", 0);
        return _logger.LogError4Boolean("仓位变化后刷新账号状态失败！");
    }
    if (!PositionState.Refresh()) {
        TradingState.PauseEntry("仓位变化后刷新持仓状态失败，暂停开仓", 0);
        return _logger.LogError4Boolean("仓位变化后刷新持仓状态失败！");
    }
    return true;
}

#endif
