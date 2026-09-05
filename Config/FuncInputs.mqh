#property strict
#ifndef ITS_FRT_CONFIG_FUNCINPUTS_MQH
#define ITS_FRT_CONFIG_FUNCINPUTS_MQH

//====================================================================
// 功能配置输入参数（ITS_FRT 精简版，仅保留实际使用的参数）
//====================================================================

//====================================================================
// 一、风控管理
//====================================================================

input group "==== 风控管理 ====";
input double InpFixedRiskEquity = 100000;         // 基准:风险预算基准净值:要求(0,+∞)
input double InpMaxRiskPerTradePct = 1.0;         // 限额:单笔最大风险率(%):要求(0,100]
input double InpMaxRiskPerDirectionPct = 3.0;     // 限额:单向最大风险率(%):要求(0,100]
input double InpCircuitBreakerDrawdownPct = 10.0; // 熔断:最大回撤率(%):要求(0,100]
input double InpMaxLotSize = 100.0;               // 限额:单笔最大手数:要求(0,+∞)
input double InpMaxMarginUsagePct = 80.0;         // 限额:最大保证金使用率(%):要求(0,100]
input double InpMinMarginLevelPct = 200.0;        // 门槛:最低保证金水平(%):要求(0,+∞)

//====================================================================
// 二、订单执行
//====================================================================

input group "==== 订单执行 ====";
input int InpSlippagePoints = 5; // 容差:最大滑点(点):要求[0,+∞)

//====================================================================
// 三、定时清仓
//====================================================================

input group "==== 定时清仓 ====";
input int InpCloseBeforeMinutes = 10; // 时段:收盘前全平仓(分钟):要求[0,+∞)
input int InpPauseBeforeMinutes = 30; // 时段:清仓前暂停开仓(分钟):要求[0,+∞)

//====================================================================
// 四、尾随止损
//====================================================================

input group "==== 尾随止损 ====";
input int InpTrailingLookbackBars = 10;       // 结构:极值回看K线数:要求[1,100]
input double InpTrailingProfitLockPct = 30.0; // 锁盈:价格百分比(%):要求[0,100]
input double InpTrailingProfitLockATR = 1.0;  // 锁盈:ATR倍数:要求[0,+∞)
input double InpTrailingMaxStopLossATR = 3.0; // 边界:最大止损距离ATR倍数:要求[0,+∞)

#endif
