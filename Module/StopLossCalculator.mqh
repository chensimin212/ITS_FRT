#property strict
#ifndef ITS_FRT_MODULE_STOP_LOSS_CALCULATOR_MQH
#define ITS_FRT_MODULE_STOP_LOSS_CALCULATOR_MQH

#include <Object.mqh>
#include "../Core/Logger.mqh"
#include "../State/_Context.mqh"

//--------------------------------------------------------------------
// CStopLossCalculator - 止损计算器（ITS_FRT 空壳）
// 保留空壳以保持架构完整性
//--------------------------------------------------------------------
class CStopLossCalculator : public CObject {
private:
    CLogger _logger;

public:
    CStopLossCalculator() {}
    ~CStopLossCalculator() {}

    bool Init(CContext *context) {
        _logger.Enable(true);
        _logger.SetModuleName("止损计算器");
        _logger.SetLogLevel(LOG_DEBUG);
        _logger.LogInfo("止损计算器初始化（空壳，ITS_FRT 不使用）");
        return true;
    }

    bool Calculate(E_ORDER_SIDE side, double entryPrice, double &stopLoss) {
        stopLoss = 0.0;
        return false;  // ITS_FRT 不使用
    }
};

#endif
