#property strict
#ifndef CONTROLLED_MARTINGALE_MANAGER_CLOSING_MANAGER_MQH
#define CONTROLLED_MARTINGALE_MANAGER_CLOSING_MANAGER_MQH

#include <Object.mqh>
#include "../Core/Enums.mqh"
#include "../Api/TradeApi.mqh"
#include "../State/_Context.mqh"
#include "../State/PositionState.mqh"
#include "../State/MarketState.mqh"
#include "../Config/BaseConfig.mqh"

//--------------------------------------------------------------------
// CClosingManager - 定时清仓管理
// 收盘前按两段窗口切换交易状态并执行清仓：
//   暂停窗口 [收盘-(清仓+暂停)分钟, 收盘-清仓分钟)：置暂停开仓态，既有仓位照常管理
//   清仓窗口 [收盘-清仓分钟, 收盘)：置清仓态并撤单平仓
// 两段窗口的恢复时间分别为清仓窗口开始时刻与收盘时刻，到期由 CTradingState 自动恢复。
// 熔断终止的清仓由 CTradingManager 独立负责，两者互不介入。
// 模式：NONE(关闭) / DAILY(每日) / FRIDAY(仅周五)
//--------------------------------------------------------------------
class CClosingManager : public CObject {
private:
    CLogger _logger;                // 时段判定与清仓诊断日志器
    CContext *_context;             // 当前 EA 的交易状态与仓位上下文
    CTradeApi *_tradeApi;           // 撤单和平仓的同步执行接口
    CBaseConfig *_config;           // 定时清仓模式与提前量配置
    CPositionState *_positionState; // 当前持仓数量，用于判断是否还需清仓
    CMarketState *_marketState;     // 当日交易时段收盘时刻来源

public:
    CClosingManager();
    ~CClosingManager() {
    }

    bool Init(CContext *context, CTradeApi *tradeApi);
    void Process();

private:
    void Liquidate();        // 撤单并平掉全部仓位
};

//--------------------------------------------------------------------
// 构造函数
//--------------------------------------------------------------------
CClosingManager::CClosingManager() {
    _context = NULL;
    _tradeApi = NULL;
    _config = NULL;
    _positionState = NULL;
    _marketState = NULL;
}

//--------------------------------------------------------------------
// 初始化
//--------------------------------------------------------------------
bool CClosingManager::Init(CContext *context, CTradeApi *tradeApi) {
    _context = context;
    _tradeApi = tradeApi;
    _config = _context.Config;
    _positionState = &_context.PositionState;
    _marketState = &_context.MarketState;

    _logger.Enable(true);
    _logger.SetModuleName("清仓管理");
    _logger.SetLogLevel(_config.LogLevel);
    return true;
}

//--------------------------------------------------------------------
// 主处理：按窗口切换交易状态并执行清仓，状态的计时与恢复由 CTradingState 负责
//--------------------------------------------------------------------
void CClosingManager::Process() {
    if (_context.TradingState.IsTerminated()) return; // 终止态的清仓由 CTradingManager 负责

    datetime now = TimeCurrent();
    datetime closeTime = _marketState.DaySessionClose;
    if (closeTime <= 0) return; // 非生效交易日或收盘时刻不可用

    datetime liquidateStart = closeTime - _config.CloseBeforeMinutes * 60;  // 清仓窗口开始时刻
    datetime pauseStart = liquidateStart - _config.PauseBeforeMinutes * 60; // 暂停窗口开始时刻

    // 清仓窗口：置清仓态并平仓，恢复时间取收盘时刻
    if (now >= liquidateStart && now < closeTime) {
        string reason = StringFormat("定时清仓：收盘前 %d 分钟", _config.CloseBeforeMinutes);
        _context.TradingState.Liquidating(reason, closeTime);
        if (_positionState.Total > 0) Liquidate();
        return;
    }

    // 暂停窗口：仅禁止开仓，既有仓位照常管理，恢复时间取清仓窗口开始时刻
    if (now >= pauseStart && now < liquidateStart) {
        string reason = StringFormat("定时清仓前暂停：收盘前 %d 分钟", _config.PauseBeforeMinutes + _config.CloseBeforeMinutes);
        _context.TradingState.PauseEntry(reason, liquidateStart);
    }
}

//--------------------------------------------------------------------
// 撤单并平掉全部仓位：未尽则由下一 bar 重试，收盘前仍有时间余量
//--------------------------------------------------------------------
void CClosingManager::Liquidate() {
    if (!_tradeApi.DeleteOrderAll()) {
        _logger.LogWarn("定时清仓：撤单未完成，下一 bar 继续");
    }

    if (!_tradeApi.ClosePositionAll()) {
        _logger.LogWarn("定时清仓：平仓未完成，下一 bar 继续");
    }

    // 刷新失败只会写入无恢复时间的暂停，不会降级当前清仓态
    _context.RefreshAfterPositionChange();
}

#endif
