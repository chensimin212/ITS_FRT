#property strict
#ifndef CONTROLLED_MARTINGALE_SIGNAL_IENTRYSIGANL_MQH
#define CONTROLLED_MARTINGALE_SIGNAL_IENTRYSIGANL_MQH

#include <Object.mqh>
#include "../Model/EntryDecision.mqh"

//--------------------------------------------------------------------
// IEntrySignal - 开仓信号统一基类接口
//
// 职责：
// - 定义所有开仓信号类的统一接口
// - 提供方向判断（多头/空头信号检查）
// - 提供完整的开仓决策（CEntryDecision）
//
// 设计原则：
// - 派生类实现具体的信号逻辑（指标、特殊时间等）
// - 派生类负责填充完整的 CEntryDecision（Action/Side/Weight/Source/Comment 等）
// - Manager 只需调用接口并执行决策，不关心具体实现细节
//--------------------------------------------------------------------
class IEntrySignal : public CObject {
public:
    //--------------------------------------------------------------------
    // 检查多头信号
    //
    // 参数:
    //   decision - 输出参数，如果有信号则填充开仓决策（Action/Side/RiskWeight/Source/Comment/SignalTime 等）
    //
    // 返回:
    //   true  - 有多头信号，decision 已填充完整
    //   false - 无多头信号或不满足条件
    //--------------------------------------------------------------------
    virtual bool CheckBuySignal(CEntryDecision &decision) = 0;

    //--------------------------------------------------------------------
    // 检查空头信号
    //
    // 参数:
    //   decision - 输出参数，如果有信号则填充开仓决策（Action/Side/RiskWeight/Source/Comment/SignalTime 等）
    //
    // 返回:
    //   true  - 有空头信号，decision 已填充完整
    //   false - 无空头信号或不满足条件
    //--------------------------------------------------------------------
    virtual bool CheckSellSignal(CEntryDecision &decision) = 0;
};

#endif
