#property strict
#ifndef ITS_FRT_MANAGER_OPENING_MANAGER_MQH
#define ITS_FRT_MANAGER_OPENING_MANAGER_MQH

#include <Object.mqh>
#include "../Core/Logger.mqh"
#include "../State/_Context.mqh"
#include "../Api/TradeApi.mqh"
#include "../Module/RiskController.mqh"

//--------------------------------------------------------------------
// COpeningManager - 首单开仓管理器（ITS_FRT 空壳）
// 保留空壳以保持架构完整性
//--------------------------------------------------------------------
class COpeningManager : public CObject {
private:
    CLogger _logger;

public:
    COpeningManager() {}
    ~COpeningManager() {}

    // 初始化
    bool Init(CContext *context, CTradeApi *tradeApi, CRiskController *riskController) {
        _logger.Enable(true);
        _logger.SetModuleName("开仓管理器");
        _logger.SetLogLevel(context.Config.LogLevel);
        _logger.LogInfo("开仓管理器初始化（空壳，ITS_FRT 不使用）");
        return true;
    }

    // 处理开仓逻辑（空壳）
    void Process() {
        // ITS_FRT 不使用开仓信号
        return;
    }
};

#endif
