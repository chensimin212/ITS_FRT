#property strict
#ifndef CONTROLLED_MARTINGALE_MODULE_RISKCONTROLLER_MQH
#define CONTROLLED_MARTINGALE_MODULE_RISKCONTROLLER_MQH

#include <Object.mqh>
#include "../Core/Logger.mqh"
#include "../Core/Enums.mqh"
#include "../State/_Context.mqh"

//--------------------------------------------------------------------
// CRiskController - 风险控制器
//--------------------------------------------------------------------
class CRiskController : public CObject {
private:
    CLogger _logger;    // 风险预算、保证金和熔断诊断日志器
    CContext *_context; // 当前 EA 的账户、品种与仓位共享上下文

    CBaseConfig *_config;           // 风险比例、最大手数和账户保护配置
    CAccountState *_accountState;   // 净值、余额、保证金与回撤事实来源
    CSymbolState *_symbolState;     // 报价、合约规格和手数边界来源
    CPositionState *_positionState; // 当前方向仓位与投影风险事实来源

public:
    CRiskController(); // 构造风险计算服务
    //--------------------------------------------------------------------
    // 析构风险控制器；共享上下文依赖不由本类释放。
    //--------------------------------------------------------------------
    ~CRiskController() {
    }

    bool Init(CContext *context);                                                                                               // 初始化
    bool IsCircuitBreaker();                                                                                                    // 是否熔断
    bool CheckLot(E_ORDER_SIDE side, double lot, double price, double sl);                                                      // 检查手数:风险额+资金使用率+可用保证金+保证金比例
    double GetRiskEquity();                                                                                                     // 风险与单笔保证金预算的基准净值
    double GetSingleRiskBudget();                                                                                               // 单笔风险预算(0=不限制时返回极大值)
    double GetDirectionRiskBudget();                                                                                            // 单向风险预算(0=不限制时返回极大值)
    double CalcAvailableMarginCapacity();                                                                                       // 当前还能新增的保证金容量
    double CalcSymbolDirectionVolume(E_ORDER_SIDE side);                                                                        // 全账户同品种同方向持仓与挂单总手数
    bool CalcMarginMoney(E_ORDER_SIDE side, double lot, double price, double &margin, bool logError = true);                    // 计算开仓保证金
    bool CalcLossMoney(E_ORDER_SIDE side, double lot, double openPrice, double closePrice, double &loss, bool logError = true); // OrderCalcProfit 计算止损损失(账户货币)
    bool CalcDirectionRisk(E_ORDER_SIDE side, double &total, bool logError = true);                                             // 合计本EA单向风险额
};

//--------------------------------------------------------------------
// 构造函数
//--------------------------------------------------------------------
CRiskController::CRiskController() {
    _context = NULL;
    _config = NULL;
    _accountState = NULL;
    _symbolState = NULL;
    _positionState = NULL;
}

//--------------------------------------------------------------------
// 初始化
//--------------------------------------------------------------------
bool CRiskController::Init(CContext *context) {
    _context = context;
    _config = context.Config;

    _accountState = &_context.AccountState;
    _symbolState = &_context.SymbolState;
    _positionState = &_context.PositionState;

    _logger.Enable(true);
    _logger.SetModuleName("风险控制器");
    _logger.SetLogLevel(_config.LogLevel);
    return true;
}

//--------------------------------------------------------------------
// 是否熔断
//--------------------------------------------------------------------
bool CRiskController::IsCircuitBreaker() {
    return (_accountState.DrawdownPct >= _config.CircuitBreakerDrawdownPct);
}

//--------------------------------------------------------------------
// 风险与单笔保证金预算基准：资金管理开按当前净值，关按固定风险净值
//--------------------------------------------------------------------
double CRiskController::GetRiskEquity() {
    return _config.FixedRiskEquity;
}

//--------------------------------------------------------------------
// 单笔风险预算：0 表示不限制
//--------------------------------------------------------------------
double CRiskController::GetSingleRiskBudget() {
    if (_config.MaxRiskPerTradePct <= 0) return 1.0e100;
    return GetRiskEquity() * (_config.MaxRiskPerTradePct / 100.0);
}

//--------------------------------------------------------------------
// 单向风险预算：0 表示不限制
//--------------------------------------------------------------------
double CRiskController::GetDirectionRiskBudget() {
    if (_config.MaxRiskPerDirectionPct <= 0) return 1.0e100;
    return GetRiskEquity() * (_config.MaxRiskPerDirectionPct / 100.0);
}

//--------------------------------------------------------------------
// 当前可新增保证金容量：同时受可用保证金与最低保证金比例约束
//--------------------------------------------------------------------
double CRiskController::CalcAvailableMarginCapacity() {
    double capacity = MathMax(_accountState.FreeMargin, 0.0);
    if (_config.MinMarginLevelPct > 0) {
        double levelCapacity = _accountState.Equity / (_config.MinMarginLevelPct / 100.0) - _accountState.Margin;
        capacity = MathMin(capacity, MathMax(levelCapacity, 0.0));
    }
    return capacity;
}

//--------------------------------------------------------------------
// 检查手数：单笔风险金额 + 单笔最大资金使用率 + 可用保证金 + 开仓后保证金比例
//--------------------------------------------------------------------
bool CRiskController::CheckLot(E_ORDER_SIDE side, double lot, double price, double sl) {
    double requestedLot = lot;
    lot = _symbolState.NormalizeVolumeDown(lot);
    if (lot <= 0) return _logger.LogError4Boolean(StringFormat("检查手数失败：手数非法或超出品种限制(%.4f)", requestedLot));
    if (lot > _config.MaxLotSize) return _logger.LogWarn4Boolean(StringFormat("超过单笔最大手数：%.2f > %.2f", lot, _config.MaxLotSize));

    // 计算基准净值：资金管理开则按当前净值，关则按固定风险净值
    double riskEquity = GetRiskEquity();

    // 本单止损损失：单笔/单向风险率共用，两率皆关或无止损则免算（OrderCalcProfit 失败保守拒单）
    double newRisk = 0.0;
    bool hasRisk = (sl > 0 && (_config.MaxRiskPerTradePct > 0 || _config.MaxRiskPerDirectionPct > 0));
    if (hasRisk && !CalcLossMoney(side, lot, price, sl, newRisk)) {
        return false;
    }

    // 1. 单笔风险率：本单止损损失不得超过 净值×单笔风险率
    if (hasRisk && _config.MaxRiskPerTradePct > 0) {
        double riskBudget = GetSingleRiskBudget();
        if (newRisk > riskBudget) {
            double slPoints = (_symbolState.Point > 0 ? MathAbs(price - sl) / _symbolState.Point : 0.0);
            return _logger.LogWarn4Boolean(StringFormat("超过单笔风险率：风险金额=%.2f > 预算=%.2f（基准净值%.2f×%.1f%%，止损%.0f点）", newRisk, riskBudget, riskEquity, _config.MaxRiskPerTradePct, slPoints));
        }
    }

    // 2. 单向合计风险率：同向已有持仓损失 + 本单损失 不得超过 净值×单向风险率
    if (hasRisk && _config.MaxRiskPerDirectionPct > 0) {
        double usedRisk = 0.0;
        if (!CalcDirectionRisk(side, usedRisk)) return false;
        double dirBudget = GetDirectionRiskBudget();
        if (usedRisk + newRisk > dirBudget) {
            double perLotRisk = (lot > 0 ? newRisk / lot : 0.0);
            double remainingLot = (perLotRisk > 0 ? MathMax((dirBudget - usedRisk) / perLotRisk, 0.0) : 0.0);
            return _logger.LogWarn4Boolean(StringFormat("超过单向风险率：合计风险额=%.2f（已用%.2f+本单%.2f）> 预算=%.2f（基准净值%.2f×%.1f%%），剩余可开%.2f手", usedRisk + newRisk, usedRisk, newRisk, dirBudget, riskEquity, _config.MaxRiskPerDirectionPct, remainingLot));
        }
    }

    // 3. 计算所需保证金（多空保证金通常一致，按买单估算即可）
    double margin = 0.0;
    if (!CalcMarginMoney(side, lot, price, margin)) return false;

    // 4. 单笔最大资金使用率：所需保证金不得超过 净值×使用率
    double budget = riskEquity * (_config.MaxMarginUsagePct / 100.0);
    if (margin > budget) {
        return _logger.LogWarn4Boolean(StringFormat("超过单笔资金使用率：所需保证金=%.2f > 预算=%.2f（基准净值%.2f×%.1f%%）", margin, budget, riskEquity, _config.MaxMarginUsagePct));
    }

    // 5. 可用保证金充足性：所需保证金不得超过当前可用保证金
    double marginCapacity = CalcAvailableMarginCapacity();
    if (margin > marginCapacity) {
        return _logger.LogWarn4Boolean(StringFormat("可新增保证金不足：所需=%.2f > 容量=%.2f", margin, marginCapacity));
    }

    // 6. 品种单向总量限制：按整个账户统计同品种同方向持仓与挂单
    if (_symbolState.LotLimit > 0) {
        double directionVolume = CalcSymbolDirectionVolume(side);
        double tolerance = _symbolState.LotStep / 2.0;
        if (directionVolume + lot > _symbolState.LotLimit + tolerance) {
            return _logger.LogWarn4Boolean(StringFormat("超过品种单向总手数限制：已有=%.2f + 本单=%.2f > 上限=%.2f", directionVolume, lot, _symbolState.LotLimit));
        }
    }

    // 7. 保证金比例：开仓后预计保证金比例不得低于下限（0 表示不限制）
    if (_config.MinMarginLevelPct > 0) {
        double projectedMargin = _accountState.Margin + margin;
        double projectedLevel = (projectedMargin > 0 ? _accountState.Equity / projectedMargin * 100.0 : 0.0);
        if (projectedMargin > 0 && projectedLevel < _config.MinMarginLevelPct) {
            return _logger.LogWarn4Boolean(StringFormat("开仓后保证金比例过低：预计=%.1f%% < 下限=%.1f%%（净值%.2f / 预计已用保证金%.2f）", projectedLevel, _config.MinMarginLevelPct, _accountState.Equity, projectedMargin));
        }
    }

    return true;
}

//--------------------------------------------------------------------
// 按方向计算开仓保证金（账户货币）
//--------------------------------------------------------------------
bool CRiskController::CalcMarginMoney(E_ORDER_SIDE side, double lot, double price, double &margin, bool logError) {
    margin = 0.0;
    ENUM_ORDER_TYPE type = (side == ORDER_SIDE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
    ResetLastError();
    if (!OrderCalcMargin(type, _config.Symbol, lot, price, margin)) {
        if (logError) return _logger.LogError4Boolean(StringFormat("计算保证金失败，错误码：%d", GetLastError()));
        return false;
    }
    return true;
}

//--------------------------------------------------------------------
// OrderCalcProfit 计算「开仓价→平仓价」的账户货币亏损（绝对值）：由经纪商口径精确换算，覆盖指数/金属/期货/跨货币品种
//--------------------------------------------------------------------
bool CRiskController::CalcLossMoney(E_ORDER_SIDE side, double lot, double openPrice, double closePrice, double &loss, bool logError) {
    loss = 0.0;
    ENUM_ORDER_TYPE type = (side == ORDER_SIDE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
    double profit = 0.0;
    ResetLastError();
    if (!OrderCalcProfit(type, _config.Symbol, lot, openPrice, closePrice, profit)) {
        if (logError) return _logger.LogError4Boolean(StringFormat("计算风险金额失败，错误码：%d", GetLastError()));
        return false;
    }
    loss = MathAbs(profit); // 止损在亏损侧，profit 为负；取绝对值与方向无关
    return true;
}

//--------------------------------------------------------------------
// 合计单向风险额：遍历同向且有效止损的持仓，逐仓用 OrderCalcProfit 累加止损损失
//--------------------------------------------------------------------
bool CRiskController::CalcDirectionRisk(E_ORDER_SIDE side, double &total, bool logError) {
    // 统计口径：多单开仓价>止损价、空单开仓价<止损价（仅统计亏损侧止损）
    total = 0.0;

    int count = ArraySize(_positionState.SnapshotList);
    for (int i = 0; i < count; i++) {
        CPositionSnapshot snapshot;
        snapshot = _positionState.SnapshotList[i];
        if (snapshot.Side != side) continue;
        if (snapshot.StopLoss <= 0) continue;
        if (side == ORDER_SIDE_BUY && snapshot.OpenPrice <= snapshot.StopLoss) continue;
        if (side == ORDER_SIDE_SELL && snapshot.OpenPrice >= snapshot.StopLoss) continue;

        double one = 0.0;
        if (!CalcLossMoney(side, snapshot.Volume, snapshot.OpenPrice, snapshot.StopLoss, one, logError)) {
            return false;
        }

        total += one;
    }
    return true;
}

//--------------------------------------------------------------------
// 全账户同品种同方向持仓与挂单总手数（经纪商 SYMBOL_VOLUME_LIMIT 口径）
//--------------------------------------------------------------------
double CRiskController::CalcSymbolDirectionVolume(E_ORDER_SIDE side) {
    double total = 0.0;
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0 || PositionGetString(POSITION_SYMBOL) != _config.Symbol) continue;
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        if (side == ORDER_SIDE_BUY && type != POSITION_TYPE_BUY) continue;
        if (side == ORDER_SIDE_SELL && type != POSITION_TYPE_SELL) continue;
        total += PositionGetDouble(POSITION_VOLUME);
    }

    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if (ticket <= 0 || OrderGetString(ORDER_SYMBOL) != _config.Symbol) continue;
        ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        bool buyOrder = (type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT ||
                         type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_STOP_LIMIT);
        bool sellOrder = (type == ORDER_TYPE_SELL || type == ORDER_TYPE_SELL_LIMIT ||
                          type == ORDER_TYPE_SELL_STOP || type == ORDER_TYPE_SELL_STOP_LIMIT);
        if ((side == ORDER_SIDE_BUY && buyOrder) || (side == ORDER_SIDE_SELL && sellOrder))
            total += OrderGetDouble(ORDER_VOLUME_CURRENT);
    }
    return total;
}

#endif
