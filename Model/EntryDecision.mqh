#property strict
#ifndef CONTROLLED_MARTINGALE_MODEL_ENTRY_DECISION_MQH
#define CONTROLLED_MARTINGALE_MODEL_ENTRY_DECISION_MQH

#include <Object.mqh>
#include "../Core/Enums.mqh"

//--------------------------------------------------------------------
// CEntryDecision - 单次开仓执行计划
//--------------------------------------------------------------------
class CEntryDecision : public CObject {
public:
    E_ENTRY_ACTION Action;
    E_ORDER_SIDE Side;
    E_RESONANCE_LEVEL ResonanceLevel; // 本次信号命中的共振档位（供加仓/补仓按档位门槛判定）
    double ReferencePrice;
    double StopLoss;
    double RiskWeight;
    double RiskMoney;
    double Volume;
    datetime SignalTime;
    string Source;
    string Comment;
    string QualityTier;  // L2新增：信号质量档位（"STD"标准/"MIN"保底）

public:
    CEntryDecision();
    ~CEntryDecision() {
    }
    void Reset();
};

//--------------------------------------------------------------------
// 构造并清空开仓计划
//--------------------------------------------------------------------
CEntryDecision::CEntryDecision() {
    Reset();
}

//--------------------------------------------------------------------
// 清空全部计划字段
//--------------------------------------------------------------------
void CEntryDecision::Reset() {
    Action = ENTRY_ACTION_NONE;
    Side = ORDER_SIDE_NONE;
    ResonanceLevel = RESONANCE_NONE;
    ReferencePrice = 0.0;
    StopLoss = 0.0;
    RiskWeight = 0.0;
    RiskMoney = 0.0;
    Volume = 0.0;
    SignalTime = 0;
    Source = "";
    Comment = "";
    QualityTier = "";  // L2新增
}

#endif
