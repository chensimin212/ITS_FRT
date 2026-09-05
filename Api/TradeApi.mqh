#property strict
#ifndef CONTROLLED_MARTINGALE_API_TRADEAPI_MQH
#define CONTROLLED_MARTINGALE_API_TRADEAPI_MQH

#include <Object.mqh>
#include <Trade/Trade.mqh>
#include "../Core/Logger.mqh"
#include "../Core/Enums.mqh"
#include "../State/_Context.mqh"

//--------------------------------------------------------------------
// CTradeApi - MT5 交易与经纪商约束封装
//--------------------------------------------------------------------
class CTradeApi : public CObject {
private:
    // 交易依赖。
    CTrade _trade;              // MT5 标准交易请求执行器及最近服务器结果来源
    CLogger _logger;            // 下单、改单、撤单和平仓执行诊断日志器
    CContext *_context;         // 当前 EA 的共享运行上下文
    CBaseConfig *_config;       // 品种、魔术号、偏差和日志等业务配置
    CSymbolState *_symbolState; // 当前报价、TickSize、StopsLevel 与手数规则

public:
    CTradeApi(); // 构造交易接口并清空运行依赖
    ~CTradeApi() {
    }

    bool Init(CContext *context); // 初始化交易接口及交易参数

    // 开仓操作。
    bool OpenOrder(const E_ORDER_SIDE side, const double volume, const double sl, const double tp, const string &comment); // 按方向市价开仓，并验证服务器结果及成交信息

    // 订单操作。
    bool DeleteOrderAll(); // 取消本 EA 的全部活动订单

    // 仓位操作。
    bool ClosePositionAll();                                                   // 关闭本 EA 的全部仓位
    bool ClosePositionBySide(const E_ORDER_SIDE side);                         // 关闭本 EA 指定方向的全部仓位
    bool ClosePositionByTicket(const ulong ticket);                            // 按 ticket 关闭本 EA 单笔仓位
    bool ModifyPosition(const ulong ticket, const double sl, const double tp); // 修改仓位止损价和止盈价

private:
    // 开仓校验与保护。
    double NormalizeVolume(const double volume);                                                                                                           // 按品种规格向下归一化手数
    double NormalizeProtectionPrice(E_ORDER_SIDE side, double price, bool isStopLoss);                                                                     // 按 TickSize 向安全方向归一化保护价
    bool IsProtectionDistanceValid(E_ORDER_SIDE side, double referencePrice, double sl, double tp);                                                        // 检查止损止盈方向和最小距离
    bool AdjustOpenedProtection(ulong positionTicket, E_ORDER_SIDE side, double referencePrice, double fillPrice, double requestedSL, double requestedTP); // 按实际成交价收紧保护价

    // 开仓成交定位。
    bool ResolvePositionByDeal(ulong dealTicket, ulong &positionTicket); // 由精确成交票据定位当前持仓

    // 订单辅助。
    bool DeleteOrderVerified(const ulong ticket); // 撤单并验证目标订单已经消失
    int GetOrderCount();                          // 获取本 EA 活动订单数
    bool IsMyOrder(const ulong ticket);           // 选中订单并判断 Symbol 和 Magic 归属

    // 仓位辅助。
    bool ClosePositionVerified(const ulong ticket); // 平仓并验证目标仓位已经消失
    int GetPositionCount();                         // 获取本 EA 当前仓位数
    bool IsMyPosition(const ulong ticket);          // 选中仓位并判断 Symbol 和 Magic 归属

    // 服务器结果判断。
    bool IsOpenRetcodeSuccess(const uint retcode);   // 开仓返回码是否表示成交成功
    bool IsModifyRetcodeSuccess(const uint retcode); // 修改返回码是否表示成功或无需变更
};

//--------------------------------------------------------------------
// 构造函数
//--------------------------------------------------------------------
CTradeApi::CTradeApi() {
    _context = NULL;
    _config = NULL;
    _symbolState = NULL;
}

//--------------------------------------------------------------------
// 初始化交易接口及交易参数
//--------------------------------------------------------------------
bool CTradeApi::Init(CContext *context) {
    _context = context;
    _config = context.Config;
    _symbolState = &context.SymbolState;

    _logger.Enable(true);
    _logger.SetModuleName("交易API");
    _logger.SetLogLevel(_config.LogLevel);

    _trade.SetExpertMagicNumber(_config.MagicNumber);
    _trade.SetDeviationInPoints(_config.SlippagePoints);
    return true;
}

//====================================================================
// 开仓主流程与保护
//====================================================================
//--------------------------------------------------------------------
// 开仓：按方向市价开仓，附带止损/止盈价
//--------------------------------------------------------------------
bool CTradeApi::OpenOrder(const E_ORDER_SIDE side, const double volume, const double sl, const double tp, const string &comment) {
    // 1. 校验交易方向和请求手数。
    if (side != ORDER_SIDE_BUY && side != ORDER_SIDE_SELL) {
        _logger.LogError("开仓方向非法");
        return false;
    }

    double normalizedVolume = NormalizeVolume(volume);
    if (normalizedVolume <= 0) {
        _logger.LogError(StringFormat("开仓手数非法：%.2f", volume));
        return false;
    }

    // 2. 根据方向取得参考价，并按品种规格归一化初始保护价。
    double referencePrice = (side == ORDER_SIDE_BUY ? _symbolState.Ask : _symbolState.Bid);
    double slPrice = NormalizeProtectionPrice(side, sl, true);
    double tpPrice = NormalizeProtectionPrice(side, tp, false);
    if (!IsProtectionDistanceValid(side, referencePrice, slPrice, tpPrice)) return false;

    // 3. 按方向提交同步市价交易请求；返回 true 仅表示请求结构与发送成功。
    ResetLastError();
    bool tradeCallSucceeded = false;
    if (side == ORDER_SIDE_BUY) {
        tradeCallSucceeded = _trade.Buy(normalizedVolume, _config.Symbol, 0.0, slPrice, tpPrice, comment);
    } else if (side == ORDER_SIDE_SELL) {
        tradeCallSucceeded = _trade.Sell(normalizedVolume, _config.Symbol, 0.0, slPrice, tpPrice, comment);
    }

    // 4. 在任何后续交易调用覆盖 CTrade 结果前，一次性固化服务器返回信息。
    uint retcode = _trade.ResultRetcode();
    ulong dealTicket = _trade.ResultDeal();
    ulong orderTicket = _trade.ResultOrder();
    double filledVolume = _trade.ResultVolume();
    double fillPrice = _trade.ResultPrice();
    int lastError = GetLastError();

    // 5. 交易调用失败时立即结束，不再处理服务器返回结果。
    if (!tradeCallSucceeded) {
        _logger.LogError(StringFormat("开仓失败：方向=%d，品种=%s，Magic=%I64d，手数=%.2f，deal=%I64u，order=%I64u，结果=%u，错误码=%d",
                                      side, _config.Symbol, _config.MagicNumber, normalizedVolume,
                                      dealTicket, orderTicket, retcode, lastError));
        return false;
    }

    // 6. 请求已被服务器接受但尚未确认成交时，保留请求并交由账户状态刷新跟踪。
    if (retcode == TRADE_RETCODE_PLACED) {
        _logger.LogWarn(StringFormat("开仓请求已放置，等待服务器成交：品种=%s，Magic=%I64d，deal=%I64u，order=%I64u，结果=%u，错误码=%d",
                                     _config.Symbol, _config.MagicNumber, dealTicket, orderTicket, retcode, lastError));
        return true;
    }

    // 7. 服务器明确未成交时，仅记录本次请求失败。
    if (!IsOpenRetcodeSuccess(retcode)) {
        _logger.LogError(StringFormat("开仓失败：方向=%d，品种=%s，Magic=%I64d，手数=%.2f，deal=%I64u，order=%I64u，结果=%u，错误码=%d",
                                      side, _config.Symbol, _config.MagicNumber, normalizedVolume,
                                      dealTicket, orderTicket, retcode, lastError));
        return false;
    }

    // 8. 验证 deal、成交量和成交价，并由 deal 定位真实持仓；验证失败不否定服务器成交结果。
    ulong positionTicket = 0;
    bool executionValid = (dealTicket > 0 && filledVolume > 0 && fillPrice > 0);
    if (executionValid) executionValid = ResolvePositionByDeal(dealTicket, positionTicket);
    if (!executionValid) {
        _logger.LogError(StringFormat("成交信息验证失败，保留服务器成交结果：品种=%s，Magic=%I64d，deal=%I64u，order=%I64u，成交量=%.2f，成交价=%.8f，结果=%u",
                                      _config.Symbol, _config.MagicNumber, dealTicket, orderTicket,
                                      filledVolume, fillPrice, retcode));
        return true;
    }

    // 9. 记录部分成交；实际成交量较小，不会扩大计划风险。
    if (retcode == TRADE_RETCODE_DONE_PARTIAL) {
        _logger.LogWarn(StringFormat("开仓部分成交：品种=%s，Magic=%I64d，请求手数=%.2f，成交手数=%.2f，deal=%I64u，order=%I64u",
                                     _config.Symbol, _config.MagicNumber, normalizedVolume, filledVolume, dealTicket, orderTicket));
    }

    // 10. 成交后按“只收紧不放宽”复核保护价；调整失败仅记录，不回滚已成交仓位。
    if (!AdjustOpenedProtection(positionTicket, side, referencePrice, fillPrice, slPrice, tpPrice)) {
        _logger.LogError(StringFormat("新仓保护调整失败，保留已成交仓位：品种=%s，Magic=%I64d，position=%I64u，deal=%I64u，order=%I64u",
                                      _config.Symbol, _config.MagicNumber, positionTicket, dealTicket, orderTicket));
    }

    // 11. 订单已经成交，开仓流程完成。
    return true;
}

//--------------------------------------------------------------------
// 归一化手数：按步进取整并约束到 [MinLot, MaxLot]
//--------------------------------------------------------------------
double CTradeApi::NormalizeVolume(const double volume) {
    return _symbolState.NormalizeVolumeDown(volume);
}

//--------------------------------------------------------------------
// 按 TickSize 向经纪商安全方向归一化保护价：止损远离市价，止盈远离开仓侧
//--------------------------------------------------------------------
double CTradeApi::NormalizeProtectionPrice(const E_ORDER_SIDE side, const double price, const bool isStopLoss) {
    if (price <= 0) return 0.0;
    double tickSize = _symbolState.TickSize;
    if (tickSize <= 0) return 0.0;

    bool roundDown = (side == ORDER_SIDE_BUY ? isStopLoss : !isStopLoss);
    double ticks = price / tickSize;
    double normalized = (roundDown ? MathFloor(ticks + 1.0e-9) : MathCeil(ticks - 1.0e-9)) * tickSize;
    return NormalizeDouble(normalized, _symbolState.Digits);
}

//--------------------------------------------------------------------
// 检查开仓保护价方向和 Stops Level，归一化后不合法则拒绝提交
//--------------------------------------------------------------------
bool CTradeApi::IsProtectionDistanceValid(const E_ORDER_SIDE side, const double referencePrice, const double sl, const double tp) {
    double minDistance = _symbolState.StopsLevel * _symbolState.Point;
    if (sl > 0) {
        double slDistance = (side == ORDER_SIDE_BUY ? referencePrice - sl : sl - referencePrice);
        if (slDistance < minDistance) return _logger.LogError4Boolean("开仓止损距离不足");
    }
    if (tp > 0) {
        double tpDistance = (side == ORDER_SIDE_BUY ? tp - referencePrice : referencePrice - tp);
        if (tpDistance < minDistance) return _logger.LogError4Boolean("开仓止盈距离不足");
    }
    return true;
}

//--------------------------------------------------------------------
// 按实际成交价收紧保护价，止损不得比请求价格更宽松
//--------------------------------------------------------------------
bool CTradeApi::AdjustOpenedProtection(const ulong positionTicket, const E_ORDER_SIDE side, const double referencePrice, const double fillPrice, const double requestedSL, const double requestedTP) {
    // 1. 无保护要求时直接成功；其余情况先确认成交仓位属于本 EA。
    if (requestedSL <= 0 && requestedTP <= 0) return true;
    if (!IsMyPosition(positionTicket)) return false;

    // 2. 按实际成交价保持原计划风险距离，并只允许把止损向更紧方向修正。
    double targetSL = requestedSL;
    double stopDistance = 0.0;
    if (requestedSL > 0) {
        stopDistance = MathAbs(referencePrice - requestedSL);
        double distanceSL = (side == ORDER_SIDE_BUY ? fillPrice - stopDistance : fillPrice + stopDistance);
        double tightenedSL = (side == ORDER_SIDE_BUY ? MathMax(requestedSL, distanceSL) : MathMin(requestedSL, distanceSL));
        targetSL = NormalizeProtectionPrice(side, tightenedSL, true);
        if (targetSL <= 0) return _logger.LogError4Boolean("实际成交止损归一化失败");

        double tolerance = _symbolState.TickSize / 2.0;
        bool targetNotLoosened = (side == ORDER_SIDE_BUY ? targetSL + tolerance >= requestedSL : targetSL - tolerance <= requestedSL);
        if (!targetNotLoosened) return _logger.LogError4Boolean("实际成交止损不得比请求止损更宽松");
    }

    // 3. 提交保护修改并重新选中持仓，确认成交后的最终保护事实。
    if (!ModifyPosition(positionTicket, targetSL, requestedTP)) return false;
    if (!IsMyPosition(positionTicket)) return false;
    if (requestedSL <= 0) return true;

    // 4. 最终止损既不能比请求价更宽，也不能超过计划风险距离。
    double finalSL = PositionGetDouble(POSITION_SL);
    double finalDistance = (finalSL > 0 ? MathAbs(fillPrice - finalSL) : 0.0);
    double tolerance = _symbolState.TickSize / 2.0;
    bool finalNotLoosened = (side == ORDER_SIDE_BUY ? finalSL + tolerance >= requestedSL : finalSL - tolerance <= requestedSL);
    bool distanceValid = (finalSL > 0 && finalDistance <= stopDistance + tolerance);
    if (finalNotLoosened && distanceValid) return true;

    _logger.LogError(StringFormat("实际成交止损验证失败：position=%I64u，实际SL=%.8f，请求SL=%.8f，实际距离=%.8f，计划距离=%.8f",
                                  positionTicket, finalSL, requestedSL, finalDistance, stopDistance));
    return false;
}

//====================================================================
// 开仓成交定位
//====================================================================
//--------------------------------------------------------------------
// 由精确成交票据定位当前持仓，失败时不发布 positionTicket
//--------------------------------------------------------------------
bool CTradeApi::ResolvePositionByDeal(const ulong dealTicket, ulong &positionTicket) {
    positionTicket = 0;
    if (dealTicket == 0 || !HistoryDealSelect(dealTicket)) return false;
    ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
    if (dealEntry != DEAL_ENTRY_IN) return false;

    ulong positionIdentifier = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
    if (positionIdentifier == 0) return false;
    for (int positionIndex = PositionsTotal() - 1; positionIndex >= 0; positionIndex--) {
        ulong currentTicket = PositionGetTicket(positionIndex);
        ulong currentIdentifier = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
        if (currentIdentifier != positionIdentifier) continue;
        positionTicket = currentTicket;
        return true;
    }
    return false;
}

//====================================================================
// 订单操作
//====================================================================
//--------------------------------------------------------------------
// 取消本 EA 的全部活动订单
//--------------------------------------------------------------------
bool CTradeApi::DeleteOrderAll() {
    bool allSucceeded = true;
    for (int orderIndex = OrdersTotal() - 1; orderIndex >= 0; orderIndex--) {
        ulong ticket = OrderGetTicket(orderIndex);
        if (!IsMyOrder(ticket)) continue;
        if (!DeleteOrderVerified(ticket)) {
            allSucceeded = false;
        }
    }

    // 二次检查
    int count = GetOrderCount();
    return (allSucceeded && count == 0);
}

//--------------------------------------------------------------------
// 撤单并验证目标订单已经消失
//--------------------------------------------------------------------
bool CTradeApi::DeleteOrderVerified(const ulong ticket) {
    // 1. 订单已不存在视为目标状态已经达成。
    if (!OrderSelect(ticket)) return true;

    // 2. 提交撤单并立即保存调用结果、服务器返回码和终端错误码。
    ResetLastError();
    bool deleteCallSucceeded = _trade.OrderDelete(ticket);
    uint retcode = _trade.ResultRetcode();
    int lastError = GetLastError();

    // 3. 请求后重新选择订单；确认消失才报告成功。
    if (!OrderSelect(ticket)) return true;

    // 4. 订单仍存在时区分本地调用失败、服务器拒绝和状态尚未同步。
    if (!deleteCallSucceeded) {
        _logger.LogError(StringFormat("撤单请求失败：ticket=%I64u，结果=%u，错误码=%d",
                                      ticket, retcode, lastError));
        return false;
    }

    if (retcode != TRADE_RETCODE_DONE) {
        _logger.LogError(StringFormat("撤单被服务器拒绝：ticket=%I64u，结果=%u，错误码=%d",
                                      ticket, retcode, lastError));
        return false;
    }

    _logger.LogWarn(StringFormat("撤单已受理但订单仍存在，等待状态同步：ticket=%I64u，结果=%u，错误码=%d",
                                 ticket, retcode, lastError));
    return false;
}

//--------------------------------------------------------------------
// 获取本 EA 活动订单数
//--------------------------------------------------------------------
int CTradeApi::GetOrderCount() {
    int count = 0;
    for (int orderIndex = OrdersTotal() - 1; orderIndex >= 0; orderIndex--) {
        ulong ticket = OrderGetTicket(orderIndex);
        if (!IsMyOrder(ticket)) continue;
        count++;
    }
    return count;
}

//--------------------------------------------------------------------
// 选中挂单并判断是否属于本 EA（Symbol + Magic）
//--------------------------------------------------------------------
bool CTradeApi::IsMyOrder(const ulong ticket) {
    if (ticket <= 0) return false;
    if (!OrderSelect(ticket)) return false;
    if (OrderGetString(ORDER_SYMBOL) != _config.Symbol) return false;
    if (OrderGetInteger(ORDER_MAGIC) != _config.MagicNumber) return false;
    return true;
}

//====================================================================
// 仓位操作
//====================================================================
//--------------------------------------------------------------------
// 关闭本 EA 的全部仓位
//--------------------------------------------------------------------
bool CTradeApi::ClosePositionAll() {
    bool allSucceeded = true;
    for (int positionIndex = PositionsTotal() - 1; positionIndex >= 0; positionIndex--) {
        ulong ticket = PositionGetTicket(positionIndex);
        if (!IsMyPosition(ticket)) continue;
        if (!ClosePositionVerified(ticket)) {
            allSucceeded = false;
        }
    }

    // 二次检查
    int count = GetPositionCount();
    return (allSucceeded && count == 0);
}

//--------------------------------------------------------------------
// 关闭指定方向全部仓位（本 EA，Symbol + Magic）
//--------------------------------------------------------------------
bool CTradeApi::ClosePositionBySide(const E_ORDER_SIDE side) {
    if (side != ORDER_SIDE_BUY && side != ORDER_SIDE_SELL) {
        return _logger.LogError4Boolean("按方向平仓失败：方向非法");
    }

    bool allSucceeded = true;
    ENUM_POSITION_TYPE type = (side == ORDER_SIDE_BUY ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
    for (int positionIndex = PositionsTotal() - 1; positionIndex >= 0; positionIndex--) {
        ulong ticket = PositionGetTicket(positionIndex);
        if (!IsMyPosition(ticket)) continue; // IsMyPosition 内已按 ticket 选中持仓，下方直接读属性
        if ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type) continue;
        if (!ClosePositionVerified(ticket)) allSucceeded = false;
    }

    // 二次检查：该方向已无本 EA 持仓才算成功
    for (int positionIndex = PositionsTotal() - 1; positionIndex >= 0; positionIndex--) {
        ulong ticket = PositionGetTicket(positionIndex);
        if (!IsMyPosition(ticket)) continue;
        if ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == type) return false;
    }
    return allSucceeded;
}

//--------------------------------------------------------------------
// 按 ticket 关闭本 EA 单笔仓位并验证结果
//--------------------------------------------------------------------
bool CTradeApi::ClosePositionByTicket(const ulong ticket) {
    if (!IsMyPosition(ticket)) return false;
    return ClosePositionVerified(ticket);
}

//--------------------------------------------------------------------
// 修改仓位：止损价、止盈价
//--------------------------------------------------------------------
bool CTradeApi::ModifyPosition(const ulong ticket, const double sl, const double tp) {
    // 1. 确认仓位归属，并按方向和品种 TickSize 归一化目标保护价。
    if (!IsMyPosition(ticket)) return false;
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    E_ORDER_SIDE side = (type == POSITION_TYPE_BUY ? ORDER_SIDE_BUY : ORDER_SIDE_SELL);
    double normalizedSL = NormalizeProtectionPrice(side, sl, true);
    double normalizedTP = NormalizeProtectionPrice(side, tp, false);

    // 2. 提交修改并同时校验终端调用结果与服务器返回码。
    ResetLastError();
    bool modifyCallSucceeded = _trade.PositionModify(ticket, normalizedSL, normalizedTP);
    uint retcode = _trade.ResultRetcode();
    int lastError = GetLastError();
    bool retcodeSucceeded = IsModifyRetcodeSuccess(retcode);
    if (!modifyCallSucceeded || !retcodeSucceeded) {
        _logger.LogWarn(StringFormat("修改仓位失败，ticket = %d，结果：%d，错误码：%d", ticket, retcode, lastError));
        return false;
    }

    // 3. 重新读取实际 SL/TP；只有两者均在半个 Tick 容差内匹配才算生效。
    if (!IsMyPosition(ticket)) return false;
    double actualSL = PositionGetDouble(POSITION_SL);
    double actualTP = PositionGetDouble(POSITION_TP);
    double tolerance = _symbolState.TickSize / 2.0;
    bool slMatches = (normalizedSL <= 0 ? actualSL <= 0 : MathAbs(actualSL - normalizedSL) < tolerance);
    bool tpMatches = (normalizedTP <= 0 ? actualTP <= 0 : MathAbs(actualTP - normalizedTP) < tolerance);
    if (!slMatches || !tpMatches) {
        _logger.LogWarn(StringFormat("修改仓位结果未生效，ticket = %d，实际SL=%.5f，目标SL=%.5f，实际TP=%.5f，目标TP=%.5f", ticket, actualSL, normalizedSL, actualTP, normalizedTP));
        return false;
    }
    return true;
}

//--------------------------------------------------------------------
// 平仓并验证目标仓位已经消失
//--------------------------------------------------------------------
bool CTradeApi::ClosePositionVerified(const ulong ticket) {
    // 1. 仓位已不存在视为目标状态已经达成。
    if (!PositionSelectByTicket(ticket)) return true;

    // 2. 提交平仓并立即保存调用结果、服务器返回码和终端错误码。
    ResetLastError();
    bool closeCallSucceeded = _trade.PositionClose(ticket);
    uint retcode = _trade.ResultRetcode();
    int lastError = GetLastError();

    // 3. 请求后重新选择仓位；确认消失才报告成功。
    if (!PositionSelectByTicket(ticket)) return true;

    // 4. 仓位仍存在时区分调用失败、服务器拒绝、部分成交和状态尚未同步。
    if (!closeCallSucceeded) {
        _logger.LogError(StringFormat("平仓请求失败：ticket=%I64u，结果=%u，错误码=%d", ticket, retcode, lastError));
        return false;
    }

    if (retcode != TRADE_RETCODE_DONE && retcode != TRADE_RETCODE_DONE_PARTIAL) {
        _logger.LogError(StringFormat("平仓被服务器拒绝：ticket=%I64u，结果=%u，错误码=%d", ticket, retcode, lastError));
        return false;
    }

    if (retcode == TRADE_RETCODE_DONE_PARTIAL) {
        _logger.LogWarn(StringFormat("仓位部分平仓：ticket=%I64u，结果=%u，错误码=%d", ticket, retcode, lastError));
        return false;
    }

    _logger.LogWarn(StringFormat("平仓已受理但仓位仍存在，等待状态同步：ticket=%I64u，结果=%u，错误码=%d", ticket, retcode, lastError));
    return false;
}

//--------------------------------------------------------------------
// 获取本 EA 当前仓位数
//--------------------------------------------------------------------
int CTradeApi::GetPositionCount() {
    int count = 0;
    for (int positionIndex = PositionsTotal() - 1; positionIndex >= 0; positionIndex--) {
        ulong ticket = PositionGetTicket(positionIndex);
        if (!IsMyPosition(ticket)) continue;
        count++;
    }
    return count;
}

//--------------------------------------------------------------------
// 选中持仓并判断是否属于本 EA（Symbol + Magic）
//--------------------------------------------------------------------
bool CTradeApi::IsMyPosition(const ulong ticket) {
    if (ticket <= 0) return false;
    if (!PositionSelectByTicket(ticket)) return false;
    if (PositionGetString(POSITION_SYMBOL) != _config.Symbol) return false;
    if (PositionGetInteger(POSITION_MAGIC) != _config.MagicNumber) return false;
    return true;
}

//====================================================================
// 服务器结果判断
//====================================================================
//--------------------------------------------------------------------
// 开仓服务器返回码是否表示请求已成交
//--------------------------------------------------------------------
bool CTradeApi::IsOpenRetcodeSuccess(const uint retcode) {
    return retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_DONE_PARTIAL;
}

//--------------------------------------------------------------------
// 改仓服务器返回码是否表示成功或无需变更
//--------------------------------------------------------------------
bool CTradeApi::IsModifyRetcodeSuccess(const uint retcode) {
    return retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_NO_CHANGES;
}

#endif
