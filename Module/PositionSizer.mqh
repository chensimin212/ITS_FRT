#property strict
#ifndef ITS_FRT_MODULE_POSITION_SIZER_MQH
#define ITS_FRT_MODULE_POSITION_SIZER_MQH

#include <Object.mqh>
#include "../Core/Logger.mqh"
#include "../State/_Context.mqh"
#include "./RiskController.mqh"

//--------------------------------------------------------------------
// CPositionSizer - 手数计算器（ITS_FRT 空壳）
// 保留空壳以保持架构完整性
//--------------------------------------------------------------------
class CPositionSizer : public CObject {
private:
    CLogger _logger;

public:
    CPositionSizer() {}
    ~CPositionSizer() {}

    bool Init(CContext *context, CRiskController *riskController) {
        _logger.Enable(true);
        _logger.SetModuleName("手数计算器");
        _logger.SetLogLevel(LOG_DEBUG);
        _logger.LogInfo("手数计算器初始化（空壳，ITS_FRT 不使用）");
        return true;
    }

    bool Calculate(E_ORDER_SIDE side, double entryPrice, double stopLoss, double weight,
                   double &riskMoney, double &volume) {
        riskMoney = 0.0;
        volume = 0.0;
        return false;  // ITS_FRT 不使用
    }
};

#endif
