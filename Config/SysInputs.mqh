#property strict
#ifndef CONTROLLED_MARTINGALE_CONFIG_SYSINPUTS_MQH
#define CONTROLLED_MARTINGALE_CONFIG_SYSINPUTS_MQH

//+------------------------------------------------------------------+
//| 输入参数区                                                       |
//+------------------------------------------------------------------+
input group "==== 系统设置 ====";
input long InpMagicNumber = 12345678;      // 标识:EA魔术号(唯一):要求>0
input double InpCommissionPerLot = 0.0;    // 成本:每手双边总佣金:要求[0,+∞)
input int InpTickPoints = 0;               // Tick:触发点数(0=禁用):要求[0,+∞)
input E_LOG_LEVEL InpLogLevel = LOG_DEBUG; // 日志:输出等级

#endif
