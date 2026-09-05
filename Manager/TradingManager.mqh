#property strict
#ifndef CONTROLLED_MARTINGALE_MANAGER_TRADING_MANAGER_MQH
#define CONTROLLED_MARTINGALE_MANAGER_TRADING_MANAGER_MQH

#include <Object.mqh>
#include "../Api/TradeApi.mqh"
#include "../State/_Context.mqh"
#include "../State/PositionState.mqh"
#include "../Config/BaseConfig.mqh"
#include "../Module/RiskController.mqh"

//--------------------------------------------------------------------
// CTradingManager - 熔断判定与终止后清仓
//   定时清仓窗口的清仓由 CClosingManager 独立负责，两者互不介入。
//--------------------------------------------------------------------
class CTradingManager : public CObject {
private:
    CLogger _logger;                  // 熔断与终止清仓诊断日志器
    CContext *_context;               // 当前 EA 的账户、仓位和交易状态上下文
    CTradeApi *_tradeApi;             // 撤单和平仓的同步执行接口
    CRiskController *_riskController; // 账户级熔断条件判断服务

    CBaseConfig *_config;           // 当前 EA 的交易与日志业务配置
    CPositionState *_positionState; // 当前持仓数量，用于判断是否还需清仓

public:
    CTradingManager(); // 构造交易风控管理器
    //--------------------------------------------------------------------
    // 析构交易风控管理器；共享上下文依赖不由本类释放。
    //--------------------------------------------------------------------
    ~CTradingManager() {
    }

    bool Init(CContext *context, CTradeApi *tradeApi, CRiskController *riskController); // 初始化
    void Process();                                                                     // 处理

private:
    void Liquidate(); // 终止后撤单并平掉全部仓位
};

//--------------------------------------------------------------------
// 构造函数
//--------------------------------------------------------------------
CTradingManager::CTradingManager() {
    _context = NULL;
    _tradeApi = NULL;
    _riskController = NULL;
    _config = NULL;
    _positionState = NULL;
}

//--------------------------------------------------------------------
// 初始化
//--------------------------------------------------------------------
bool CTradingManager::Init(CContext *context, CTradeApi *tradeApi, CRiskController *riskController) {
    _context = context;
    _tradeApi = tradeApi;
    _riskController = riskController;

    _config = _context.Config;
    _positionState = &_context.PositionState;

    _logger.Enable(true);
    _logger.SetModuleName("交易管理器");
    _logger.SetLogLevel(_config.LogLevel);
    return true;
}

//--------------------------------------------------------------------
// 处理：熔断判定与终止后清仓
//--------------------------------------------------------------------
void CTradingManager::Process() {
    // 1. 回撤超过配置值即终止交易；Terminate 内部已记日志且幂等
    if (_riskController.IsCircuitBreaker()) {
        _context.TradingState.Terminate("已触发熔断");
    }

    // 2. 终止态需平掉全部仓位；未尽则下一 bar 继续重试
    if (_context.TradingState.IsTerminated()) {
        Liquidate();
    }
}

//--------------------------------------------------------------------
// 终止后撤单并平掉全部仓位：失败即人工干预范畴，记 ERROR
//--------------------------------------------------------------------
void CTradingManager::Liquidate() {
    if (_positionState.Total <= 0) return;

    if (!_tradeApi.DeleteOrderAll()) {
        _logger.LogError("终止清仓：撤单失败");
    }

    if (!_tradeApi.ClosePositionAll()) {
        _logger.LogError("终止清仓：平仓失败");
    }

    // 刷新失败只会写入无恢复时间的暂停，不会降级当前终止态
    _context.RefreshAfterPositionChange();
}

#endif
