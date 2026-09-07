#property strict
#ifndef CONTROLLED_MARTINGALE_MANAGER_TRAILINGMANAGER_MQH
#define CONTROLLED_MARTINGALE_MANAGER_TRAILINGMANAGER_MQH

#include <Object.mqh>
#include "../Api/TradeApi.mqh"
#include "../State/_Context.mqh"
#include "../State/SymbolState.mqh"
#include "../State/PositionState.mqh"
#include "../State/MarketState.mqh"
#include "../Core/Consts.mqh"

//--------------------------------------------------------------------
// CTrailingManager - 尾随止损管理器
//
// 职责：维护已有持仓的止损，按极值窗口跟踪市场移动
// 触发：OnTick 门控（新 bar 或新价格）后由组成根调用
// 保护策略：
//   - 篮子锁盈（方向组合级）：整体锁盈 > 0 时，统一推进所有同向腿
//   - 逐笔锁盈（仓位级）：单笔盈利达到锁盈距离时，推进该腿止损
// 基础止损：锚定周期的已收 K 极值外留缓冲，并受 ATR 倍数封顶
// 锚定周期：固定取做单周期（TradeTimeframe）
//--------------------------------------------------------------------
class CTrailingManager : public CObject {
private:
    CLogger _logger;
    CContext *_context;
    CTradeApi *_tradeApi;
    CBaseConfig *_config;
    CSymbolState *_symbolState;
    CPositionState *_positionState;
    CMarketState *_marketState;

public:
    CTrailingManager();
    ~CTrailingManager() {
    }

    bool Init(CContext *context, CTradeApi *tradeApi);
    void Process();

private:
    // ======== 主流程 ========
    bool ProcessSide(const E_ORDER_SIDE side); // 处理单个方向：篮子优先 → 逐笔兜底

    // ======== 篮子锁盈（方向组合级保护）========
    bool TryBasketLock(const E_ORDER_SIDE side, const double newSL, bool &positionChanged);
    bool CalcCandidateLockedNetProfit(const E_ORDER_SIDE side, const double candidateSL, double &netProfit);

    // ======== 逐笔锁盈（单腿保护）========
    bool TrailLegs(const E_ORDER_SIDE side, const double newSL);
    double ProfitLockDistance(const E_ORDER_SIDE side); // 逐笔锁盈距离：max(当前价百分比, ATR 倍数)

    // ======== 基础止损计算 ========
    double AnchorATR();                              // 锚定周期的 ATR
    ENUM_TIMEFRAMES AnchorTimeframe();               // 锚定周期：做单周期
    double CalcNewStopLoss(const E_ORDER_SIDE side); // 极值窗口外缓冲，ATR 封顶

    // ======== 安全提交 ========
    bool Commit(const CPositionSnapshot &pos, const double candidateSL, const string phase);
    double NormalizeStopLoss(const E_ORDER_SIDE side, const double sl); // TickSize 归一化
};

//--------------------------------------------------------------------
// 构造
//--------------------------------------------------------------------
CTrailingManager::CTrailingManager() {
    _context = NULL;
    _tradeApi = NULL;
    _config = NULL;
    _symbolState = NULL;
    _positionState = NULL;
    _marketState = NULL;
}

//--------------------------------------------------------------------
// 初始化
//--------------------------------------------------------------------
bool CTrailingManager::Init(CContext *context, CTradeApi *tradeApi) {
    _context = context;
    _tradeApi = tradeApi;
    _config = _context.Config;
    _symbolState = &_context.SymbolState;
    _positionState = &_context.PositionState;
    _marketState = &_context.MarketState;

    _logger.Enable(true);
    _logger.SetModuleName("尾随管理器");
    _logger.SetLogLevel(_config.LogLevel);
    return true;
}

//--------------------------------------------------------------------
// 处理：锚定周期 ATR 未就绪则跳过，否则依次处理多空方向
//--------------------------------------------------------------------
void CTrailingManager::Process() {
    if (AnchorATR() <= 0) {
        _logger.LogDebug("锚定周期ATR未就绪，跳过本轮尾随");
        return;
    }

    bool buyChanged = ProcessSide(ORDER_SIDE_BUY);
    bool sellChanged = ProcessSide(ORDER_SIDE_SELL);
    if (buyChanged || sellChanged) {
        _context.RefreshAfterPositionChange();
    }
}

//--------------------------------------------------------------------
// 处理单个方向：计算基础止损，优先篮子锁盈，未触发则回退逐笔锁盈
//--------------------------------------------------------------------
bool CTrailingManager::ProcessSide(const E_ORDER_SIDE side) {
    CDirectionSequence *sequence = (side == ORDER_SIDE_BUY ? &_positionState.BuySequence : &_positionState.SellSequence);
    if (sequence.PositionCount <= 0) return false;

    // 计算基础止损
    double newSL = CalcNewStopLoss(side);
    if (newSL <= 0) {
        _logger.LogDebug(StringFormat("%s方向极值数据缺失，跳过尾随", side == ORDER_SIDE_BUY ? "多" : "空"));
        return false;
    }

    // 优先篮子锁盈（方向组合级）
    bool basketChanged = false;
    if (TryBasketLock(side, newSL, basketChanged)) return basketChanged;

    // 篮子未触发，回退逐笔锁盈（仓位级）
    return TrailLegs(side, newSL);
}

//--------------------------------------------------------------------
// 尝试篮子锁盈：方向整体按 newSL 退出后锁定净收益 > 0 时，统一推进所有同向腿
//--------------------------------------------------------------------
bool CTrailingManager::TryBasketLock(const E_ORDER_SIDE side, const double newSL, bool &positionChanged) {
    positionChanged = false;

    // 计算方向整体按 newSL 退出的锁定净收益
    double candidateLockedNetProfit = 0.0;
    if (!CalcCandidateLockedNetProfit(side, newSL, candidateLockedNetProfit)) return false;
    if (candidateLockedNetProfit <= 0) return false;

    // 推进所有同向腿（包括单笔亏损但组合整体盈利的腿）
    int count = ArraySize(_positionState.SnapshotList);
    for (int i = 0; i < count; i++) {
        CPositionSnapshot pos;
        pos = _positionState.SnapshotList[i];
        if (pos.Side != side) continue;
        if (Commit(pos, newSL, "篮子锁盈")) positionChanged = true;
    }

    return true; // 返回 true 阻断后续逐笔锁盈
}

//--------------------------------------------------------------------
// 计算候选止损下的方向锁定净收益
// 逻辑：逐仓估算，已有更优止损的保持不变，取 max(现有 SL, candidateSL)
//--------------------------------------------------------------------
bool CTrailingManager::CalcCandidateLockedNetProfit(const E_ORDER_SIDE side, const double candidateSL, double &netProfit) {
    netProfit = 0.0;
    double normalizedCandidateSL = NormalizeStopLoss(side, candidateSL);
    if (normalizedCandidateSL <= 0) return false;

    int count = ArraySize(_positionState.SnapshotList);
    bool found = false;
    for (int i = 0; i < count; i++) {
        CPositionSnapshot snapshot;
        snapshot = _positionState.SnapshotList[i];
        if (snapshot.Side != side) continue;
        found = true;

        // 已有更优止损的保持不变
        double effectiveSL = normalizedCandidateSL;
        if (snapshot.StopLoss > 0) {
            effectiveSL = (side == ORDER_SIDE_BUY ? MathMax(snapshot.StopLoss, normalizedCandidateSL) : MathMin(snapshot.StopLoss, normalizedCandidateSL));
        }

        double oneNetProfit = 0.0;
        if (!_positionState.CalcProtectedNetProfit(snapshot, effectiveSL, oneNetProfit)) return false;
        netProfit += oneNetProfit;
    }

    return found;
}

//--------------------------------------------------------------------
// 逐笔锁盈：基础止损达到本笔开仓价外锁盈距离后，推进该笔止损
//--------------------------------------------------------------------
bool CTrailingManager::TrailLegs(const E_ORDER_SIDE side, const double newSL) {
    bool positionChanged = false;
    double profitLockDist = ProfitLockDistance(side);

    int count = ArraySize(_positionState.SnapshotList);
    for (int i = 0; i < count; i++) {
        CPositionSnapshot pos;
        pos = _positionState.SnapshotList[i];
        if (pos.Side != side) continue;

        // 计算该笔的锁盈线：开仓价外 profitLockDist
        double profitLockSL = (side == ORDER_SIDE_BUY ? pos.OpenPrice + profitLockDist : pos.OpenPrice - profitLockDist);
        bool isLocked = (side == ORDER_SIDE_BUY ? newSL >= profitLockSL : newSL <= profitLockSL);
        if (!isLocked) continue;

        if (Commit(pos, newSL, "逐笔锁盈")) positionChanged = true;
    }
    return positionChanged;
}

//--------------------------------------------------------------------
// 逐笔锁盈距离：当前价百分比与 ATR 倍数取大，兼顾价格尺度与波动
//--------------------------------------------------------------------
double CTrailingManager::ProfitLockDistance(const E_ORDER_SIDE side) {
    double currentPrice = (side == ORDER_SIDE_BUY ? _symbolState.Bid : _symbolState.Ask);
    double pricePctDist = currentPrice * _config.TrailingProfitLockPct / 100.0;
    double atrDist = AnchorATR() * _config.TrailingProfitLockATR;
    return MathMax(pricePctDist, atrDist);
}

//--------------------------------------------------------------------
// 计算方向基础止损：锚定周期已收 K 极值外留超幅比例缓冲，并限制最大止损距离
//--------------------------------------------------------------------
double CTrailingManager::CalcNewStopLoss(const E_ORDER_SIDE side) {
    ENUM_TIMEFRAMES timeframe = AnchorTimeframe();
    double maxStopDist = AnchorATR() * _config.TrailingMaxStopLossATR;

    if (side == ORDER_SIDE_BUY) {
        double price = _symbolState.Bid;
        double extLow = _marketState.LowestPriceOn(timeframe, _config.TrailingLookbackBars, 1);
        if (extLow <= 0) return 0.0;

        // 缓冲 = 现价超出极值的幅度 × 5%（回调未跌破极值时留噪声余量）
        double buffer = MathMax(price - extLow, 0.0) * TRAILING_BUFFER_RATIO;
        // 止损 = max(极值外缓冲, 现价外最大距离)（后者封顶，防止异常波动时过远）
        return MathMax(extLow - buffer, price - maxStopDist);
    }

    if (side == ORDER_SIDE_SELL) {
        double price = _symbolState.Ask;
        double extHigh = _marketState.HighestPriceOn(timeframe, _config.TrailingLookbackBars, 1);
        if (extHigh <= 0) return 0.0;

        double buffer = MathMax(extHigh - price, 0.0) * TRAILING_BUFFER_RATIO;
        return MathMin(extHigh + buffer, price + maxStopDist);
    }
    return 0.0;
}

//--------------------------------------------------------------------
// 锚定周期：固定取做单周期（TradeTimeframe）
//--------------------------------------------------------------------
ENUM_TIMEFRAMES CTrailingManager::AnchorTimeframe() {
    return _config.TradeTimeframe;
}

//--------------------------------------------------------------------
// 锚定周期的 ATR：缓冲上限与锁盈距离必须同周期，否则量纲不匹配
//--------------------------------------------------------------------
double CTrailingManager::AnchorATR() {
    return _marketState.TradeATR;
}

//--------------------------------------------------------------------
// 安全提交止损：单向移动、Stops/Freeze 距离、TickSize 归一化、防重复提交
//--------------------------------------------------------------------
bool CTrailingManager::Commit(const CPositionSnapshot &pos, const double candidateSL, const string phase) {
    double newSL = NormalizeStopLoss(pos.Side, candidateSL);
    if (newSL <= 0) return false;

    double tickSize = _symbolState.TickSize;

    // 单向移动检查：多单止损只能上移，空单止损只能下移
    if (pos.StopLoss > 0) {
        if (pos.Side == ORDER_SIDE_BUY && newSL - pos.StopLoss < tickSize) return false;
        if (pos.Side == ORDER_SIDE_SELL && pos.StopLoss - newSL < tickSize) return false;
    }

    // Stops/Freeze Level 距离检查
    long protectionLevel = (long)MathMax(_symbolState.StopsLevel, _symbolState.FreezeLevel);
    double minDistance = protectionLevel * _symbolState.Point;
    if (pos.Side == ORDER_SIDE_BUY && _symbolState.Bid - newSL < minDistance) return false;
    if (pos.Side == ORDER_SIDE_SELL && newSL - _symbolState.Ask < minDistance) return false;

    // 提交改单
    int digits = _symbolState.Digits;
    if (_tradeApi.ModifyPosition(pos.Ticket, newSL, pos.TakeProfit)) {
        _logger.LogInfo(StringFormat("尾随[%s] #%d SL:%.*f→%.*f", phase, pos.Ticket, digits, pos.StopLoss, digits, newSL));
        return true;
    }
    return false;
}

//--------------------------------------------------------------------
// TickSize 归一化：多单向下取整（安全方向），空单向上取整
//--------------------------------------------------------------------
double CTrailingManager::NormalizeStopLoss(const E_ORDER_SIDE side, const double sl) {
    double tickSize = _symbolState.TickSize;
    if (sl <= 0 || tickSize <= 0) return 0.0;

    double steps = sl / tickSize;
    double normalized = (side == ORDER_SIDE_BUY ? MathFloor(steps) * tickSize : MathCeil(steps) * tickSize);
    return NormalizeDouble(normalized, _symbolState.Digits);
}

#endif
