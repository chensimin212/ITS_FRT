#property strict
#ifndef CONTROLLED_MARTINGALE_STATE_POSITIONSTATE_MQH
#define CONTROLLED_MARTINGALE_STATE_POSITIONSTATE_MQH

#include <Object.mqh>
#include "../Core/Logger.mqh"
#include "../Model/PositionSnapshot.mqh"
#include "../Model/DirectionSequence.mqh"

//--------------------------------------------------------------------
// CPositionState - 持仓状态
//--------------------------------------------------------------------
class CPositionState : public CObject {
private:
    CLogger _logger;      // 持仓刷新与风险精算日志器
    CBaseConfig *_config; // 当前 EA 的只读配置来源

public:
    int Total;                        // 当前品种、当前 Magic 的未平仓总数
    int TotalBuy;                     // 当前有效多头未平仓数量
    int TotalSell;                    // 当前有效空头未平仓数量
    CDirectionSequence BuySequence;   // 当前多头仓位的生命周期与保护状态聚合
    CDirectionSequence SellSequence;  // 当前空头仓位的生命周期与保护状态聚合
    CPositionSnapshot SnapshotList[]; // 本轮刷新得到的全部当前持仓快照，不包含历史和平仓订单
    long Version;                     // 每次成功刷新当前仓位集合后递增的仓位版本

public:
    CPositionState();  // 构造并清空当前持仓聚合状态
    ~CPositionState(); // 析构持仓状态对象

    bool Init(CBaseConfig *config);                                                                           // 注入配置并完成首次刷新；失败返回 false
    bool Refresh();                                                                                           // 刷新当前持仓快照和方向聚合状态；失败返回 false
    bool FindSnapshotByTicket(ulong ticket, CPositionSnapshot &out);                                          // 按单号查找当前快照；未找到时不修改输出参数并返回 false
    bool CalcProtectedNetProfit(const CPositionSnapshot &snapshot, const double stopLoss, double &netProfit); // 计算指定保护价退出时的账户货币净收益

private:
    void Reset();                                                                                                                                // 清空本轮聚合状态
    void ApplySequence(CDirectionSequence &sequence, const CPositionSnapshot &snapshot, const bool hasProtection, const double lockedNetProfit); // 累计方向事实
    E_ORDER_SIDE ToOrderSide(ENUM_POSITION_TYPE type);                                                                                           // 转换平台持仓类型；未知类型返回 ORDER_SIDE_NONE
    int ParseLayer(const string comment, const string prefix);                                                                                  // 解析A/R数字层级，非法返回0
};

//--------------------------------------------------------------------
// 构造持仓状态并初始化多空方向序列
//--------------------------------------------------------------------
CPositionState::CPositionState() {
    _config = NULL;

    Total = 0;
    TotalBuy = 0;
    TotalSell = 0;
    Version = 0;
    BuySequence.Reset(ORDER_SIDE_BUY);
    SellSequence.Reset(ORDER_SIDE_SELL);
    ArrayFree(SnapshotList);
}

//--------------------------------------------------------------------
// 析构持仓状态
//--------------------------------------------------------------------
CPositionState::~CPositionState() {
}

//--------------------------------------------------------------------
// 注入配置、初始化模块日志并完成首次持仓刷新
//--------------------------------------------------------------------
bool CPositionState::Init(CBaseConfig *config) {
    _config = config;

    _logger.Enable(true);
    _logger.SetModuleName("持仓状态");
    _logger.SetLogLevel(_config.LogLevel);

    return Refresh();
}

//--------------------------------------------------------------------
// 刷新本 EA 在当前品种上的持仓快照及多空方向聚合状态
//--------------------------------------------------------------------
bool CPositionState::Refresh() {
    // 先清空上一轮派生状态；任一平台读取失败时再次清空，避免发布半成品快照。
    Reset();

    // 只接纳当前配置品种和 Magic 的未平仓订单，并逐笔构造统一快照。
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; --i) {
        ulong ticket = PositionGetTicket(i);
        if (ticket == 0) {
            _logger.LogError(StringFormat("读取持仓单号失败：索引=%d", i));
            continue;
        }
        if (!PositionSelectByTicket(ticket)) {
            _logger.LogError(StringFormat("选择持仓失败：单号=%I64u", ticket));
            continue;
        }
        if (PositionGetString(POSITION_SYMBOL) != _config.Symbol) continue;
        if (PositionGetInteger(POSITION_MAGIC) != _config.MagicNumber) continue;

        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

        // 构建当前持仓快照。
        CPositionSnapshot snapshot;
        snapshot.Ticket = ticket;
        snapshot.Symbol = _config.Symbol;
        snapshot.Magic = _config.MagicNumber;
        snapshot.Side = ToOrderSide(type);
        snapshot.Volume = PositionGetDouble(POSITION_VOLUME);
        snapshot.Commission = -snapshot.Volume * _config.CommissionPerLot;
        snapshot.OpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        snapshot.StopLoss = PositionGetDouble(POSITION_SL);
        snapshot.TakeProfit = PositionGetDouble(POSITION_TP);
        snapshot.Profit = PositionGetDouble(POSITION_PROFIT);
        snapshot.OpenTime = (datetime)PositionGetInteger(POSITION_TIME);
        snapshot.OpenTimeMsc = PositionGetInteger(POSITION_TIME_MSC);
        snapshot.Comment = PositionGetString(POSITION_COMMENT);
        snapshot.Swap = PositionGetDouble(POSITION_SWAP);

        // 计算已锁定利润：若当前持仓有止损保护价，则按保护价退出时的净收益计算锁定利润；否则为 0。
        double lockedNetProfit = 0.0;
        bool hasProtection = snapshot.StopLoss > 0;
        if (hasProtection && CalcProtectedNetProfit(snapshot, snapshot.StopLoss, lockedNetProfit)) {
            snapshot.LockedNetProfit = lockedNetProfit;
            snapshot.LegLocked = lockedNetProfit > 0;
        }

        // 将持仓快照追加到本轮快照列表。
        int n = ArraySize(SnapshotList);
        ArrayResize(SnapshotList, n + 1);
        SnapshotList[n] = snapshot;

        // 将持仓数据汇总到对应方向序列。
        Total++;
        if (type == POSITION_TYPE_BUY) {
            TotalBuy++;
            ApplySequence(BuySequence, snapshot, hasProtection, lockedNetProfit);
        } else if (type == POSITION_TYPE_SELL) {
            TotalSell++;
            ApplySequence(SellSequence, snapshot, hasProtection, lockedNetProfit);
        }
    }

    // L3新增：计算锁盈比例
    if (BuySequence.PositionCount > 0) {
        BuySequence.LockRatio = (double)BuySequence.LockedCount / BuySequence.PositionCount;
    } else {
        BuySequence.LockRatio = 0.0;
    }
    if (SellSequence.PositionCount > 0) {
        SellSequence.LockRatio = (double)SellSequence.LockedCount / SellSequence.PositionCount;
    } else {
        SellSequence.LockRatio = 0.0;
    }

    Version++;
    return true;
}

//--------------------------------------------------------------------
// 按单号查找当前快照
//--------------------------------------------------------------------
bool CPositionState::FindSnapshotByTicket(ulong ticket, CPositionSnapshot &out) {
    int size = ArraySize(SnapshotList);
    for (int i = 0; i < size; i++) {
        if (SnapshotList[i].Ticket == ticket) {
            out = SnapshotList[i];
            return true;
        }
    }
    return false;
}

//--------------------------------------------------------------------
// 清空本轮持仓快照与方向聚合状态
//--------------------------------------------------------------------
void CPositionState::Reset() {
    // 重置多空方向序列。
    BuySequence.Reset(ORDER_SIDE_BUY);
    SellSequence.Reset(ORDER_SIDE_SELL);

    // 清空当前快照列表和持仓计数。
    ArrayFree(SnapshotList);
    ArrayResize(SnapshotList, 0);

    Total = 0;
    TotalBuy = 0;
    TotalSell = 0;
}

//--------------------------------------------------------------------
// 计算指定保护价退出时的账户货币净收益，平台精算失败时按 Tick 比例降级
//--------------------------------------------------------------------
bool CPositionState::CalcProtectedNetProfit(const CPositionSnapshot &snapshot, const double stopLoss, double &netProfit) {
    netProfit = 0.0;
    if (stopLoss <= 0) return false;

    ENUM_ORDER_TYPE type = (snapshot.Side == ORDER_SIDE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
    double priceProfit = 0.0;
    ResetLastError();
    if (!OrderCalcProfit(type, snapshot.Symbol, snapshot.Volume, snapshot.OpenPrice, stopLoss, priceProfit)) {
        int errorCode = GetLastError();
        double priceDistance = (snapshot.Side == ORDER_SIDE_BUY ? stopLoss - snapshot.OpenPrice : snapshot.OpenPrice - stopLoss);
        double tickSize = SymbolInfoDouble(snapshot.Symbol, SYMBOL_TRADE_TICK_SIZE);
        ENUM_SYMBOL_INFO_DOUBLE tickValueProperty = (priceDistance >= 0 ? SYMBOL_TRADE_TICK_VALUE_PROFIT : SYMBOL_TRADE_TICK_VALUE_LOSS);
        double tickValue = SymbolInfoDouble(snapshot.Symbol, tickValueProperty);
        if (tickValue <= 0) tickValue = SymbolInfoDouble(snapshot.Symbol, SYMBOL_TRADE_TICK_VALUE);
        if (tickSize <= 0 || tickValue <= 0) {
            return _logger.LogError4Boolean(StringFormat("比例估算保护价净收益失败：单号=%I64u，错误码=%d", snapshot.Ticket, errorCode));
        }

        priceProfit = priceDistance / tickSize * tickValue * snapshot.Volume;
        _logger.LogWarn(StringFormat("平台估算保护价净收益失败，已按 Tick 比例降级：单号=%I64u，错误码=%d", snapshot.Ticket, errorCode));
    }

    netProfit = priceProfit + snapshot.Swap + snapshot.Commission;
    return true;
}

//--------------------------------------------------------------------
// 将单个持仓快照累计到指定方向序列
//--------------------------------------------------------------------
void CPositionState::ApplySequence(CDirectionSequence &sequence, const CPositionSnapshot &snapshot, const bool hasProtection, const double lockedNetProfit) {
    sequence.PositionCount++;
    sequence.AllProtected = (sequence.PositionCount == 1 ? hasProtection : sequence.AllProtected && hasProtection);
    sequence.LockedNetProfit += lockedNetProfit;
    int rescueLayer = ParseLayer(snapshot.Comment, "R");
    int addLayer = ParseLayer(snapshot.Comment, "A");
    if (rescueLayer > sequence.RescueCount) sequence.RescueCount = rescueLayer;
    if (addLayer > sequence.AddCount) sequence.AddCount = addLayer;
    sequence.TotalVolume += snapshot.Volume;
    sequence.TotalNetProfit += snapshot.Profit + snapshot.Swap + snapshot.Commission;

    // 逐笔锁盈：每笔按自身保护价退出均须净收益为正（严于方向合计口径，供盈利加仓判定）
    bool legLocked = (hasProtection && lockedNetProfit > 0);
    sequence.AllLegLocked = (sequence.PositionCount == 1 ? legLocked : sequence.AllLegLocked && legLocked);

    // L3新增：累计锁盈数量
    if (legLocked) {
        sequence.LockedCount++;
    }

    // 同向最保守保护价：多单取最小止损、空单取最大止损，供加仓/补仓共用；
    // 任一笔无保护价即置 0 并保持为 0（此时无法给新增仓位继承一个可靠的共用止损）
    if (sequence.PositionCount == 1) {
        sequence.ProtectiveStopLoss = (hasProtection ? snapshot.StopLoss : 0.0);
    } else if (!hasProtection || sequence.ProtectiveStopLoss <= 0) {
        sequence.ProtectiveStopLoss = 0.0;
    } else {
        sequence.ProtectiveStopLoss = (snapshot.Side == ORDER_SIDE_BUY ? MathMin(sequence.ProtectiveStopLoss, snapshot.StopLoss) : MathMax(sequence.ProtectiveStopLoss, snapshot.StopLoss));
    }

    // 更新当前方向最新持仓。
    if (sequence.LatestOpenTimeMsc <= 0 ||
        snapshot.OpenTimeMsc > sequence.LatestOpenTimeMsc ||
        (snapshot.OpenTimeMsc == sequence.LatestOpenTimeMsc && snapshot.Ticket > sequence.LatestTicket)) {
        sequence.LatestTicket = snapshot.Ticket;
        sequence.LatestOpenPrice = snapshot.OpenPrice;
        sequence.LatestOpenTime = snapshot.OpenTime;
        sequence.LatestOpenTimeMsc = snapshot.OpenTimeMsc;
    }

    // 选择仍亏损且最接近盈亏平衡的仓位，供补仓距离判断。
    double currentPrice = (snapshot.Side == ORDER_SIDE_BUY
                               ? SymbolInfoDouble(snapshot.Symbol, SYMBOL_BID)
                               : SymbolInfoDouble(snapshot.Symbol, SYMBOL_ASK));
    double adverseDistance = (snapshot.Side == ORDER_SIDE_BUY
                                  ? snapshot.OpenPrice - currentPrice
                                  : currentPrice - snapshot.OpenPrice);
    bool closer = !sequence.HasLosingLeg || adverseDistance < sequence.LeastLosingAdverseDistance;
    bool sameDistance = sequence.HasLosingLeg && MathAbs(adverseDistance - sequence.LeastLosingAdverseDistance) <= 1.0e-12;
    bool later = snapshot.OpenTimeMsc > sequence.LeastLosingOpenTimeMsc ||
                 (snapshot.OpenTimeMsc == sequence.LeastLosingOpenTimeMsc && snapshot.Ticket > sequence.LeastLosingTicket);
    if (currentPrice > 0 && adverseDistance > 0 && (closer || (sameDistance && later))) {
        sequence.HasLosingLeg = true;
        sequence.LeastLosingTicket = snapshot.Ticket;
        sequence.LeastLosingOpenPrice = snapshot.OpenPrice;
        sequence.LeastLosingAdverseDistance = adverseDistance;
        sequence.LeastLosingOpenTimeMsc = snapshot.OpenTimeMsc;
    }
}

//--------------------------------------------------------------------
// 解析A/R开仓注释中的正整数层级
//--------------------------------------------------------------------
int CPositionState::ParseLayer(const string comment, const string prefix) {
    if (StringFind(comment, prefix) != 0 || StringLen(comment) <= StringLen(prefix)) return 0;
    string suffix = StringSubstr(comment, StringLen(prefix));
    for (int index = 0; index < StringLen(suffix); index++) {
        ushort character = StringGetCharacter(suffix, index);
        if (character < '0' || character > '9') return 0;
    }
    int layer = (int)StringToInteger(suffix);
    return (layer > 0 ? layer : 0);
}

//--------------------------------------------------------------------
// 将平台持仓类型转换为 EA 订单方向；未知类型返回 ORDER_SIDE_NONE
//--------------------------------------------------------------------
E_ORDER_SIDE CPositionState::ToOrderSide(ENUM_POSITION_TYPE type) {
    switch (type) {
    case POSITION_TYPE_BUY:
        return ORDER_SIDE_BUY;
    case POSITION_TYPE_SELL:
        return ORDER_SIDE_SELL;
    default:
        return ORDER_SIDE_NONE;
    }
}

#endif
//+------------------------------------------------------------------+
