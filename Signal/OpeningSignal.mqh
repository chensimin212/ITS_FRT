#property strict
#ifndef ITS_FRT_SIGNAL_OPENINGSIGNAL_MQH
#define ITS_FRT_SIGNAL_OPENINGSIGNAL_MQH

#include "../Core/Enums.mqh"
#include "../Model/EntryDecision.mqh"
#include "./IEntrySignal.mqh"

//--------------------------------------------------------------------
// COpeningSignal - 开仓信号空壳（ITS_FRT 不使用）
// 保留空壳以保持架构完整性
//--------------------------------------------------------------------
class COpeningSignal : public IEntrySignal {
public:
    bool Evaluate(const E_ORDER_SIDE side, CEntryDecision &decision) override {
        return false;  // ITS_FRT 不使用开仓信号
    }

    string ModuleName() {
        return "开仓信号（空壳）";
    }
};

#endif
