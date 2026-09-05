//+------------------------------------------------------------------+
//|                                                 ITS_FRT_V1.0.mq5 |
//|                                        Copyright 2026, RockChen. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, RockChen"
#property link "https://www.mql5.com"
#property version "1.0"
#property description "日内交易系统·固定风险·区间套利 V1.0"

//+------------------------------------------------------------------+
//|                          引入模块                                |
//+------------------------------------------------------------------+
#include "./Core/Consts.mqh"             // 常量模块
#include "./Core/Logger.mqh"             // 日志模块
#include "./State/_Context.mqh"          // 上下文模块
#include "./Api/TradeApi.mqh"            // 交易接口
#include "./Module/RiskController.mqh"   // 风险控制器
#include "./Manager/TradingManager.mqh"  // 交易管理（熔断）
#include "./Manager/ClosingManager.mqh"  // 定时清仓管理
#include "./Manager/OpeningManager.mqh"  // 首单开仓管理
#include "./Manager/TrailingManager.mqh" // 尾随止损管理

// 配置模块（条件编译）
#ifdef USE_PRO_CONFIG
#include "./Config/ProConfig.mqh"
CProConfig _gConfig;
#else
#include "./Config/TestConfig.mqh"
CTestConfig _gConfig;
#endif

//+------------------------------------------------------------------+
//|                          全局变量                                |
//+------------------------------------------------------------------+
CLogger _gLogger;                 // 全局日志器
CContext _gContext;               // 全局上下文
CTradeApi _gTradeApi;             // 交易 API
CRiskController _gRiskController; // 风险控制器

// 业务管理器
CTradingManager _gTradingManager;   // 熔断管理
CClosingManager _gClosingManager;   // 定时清仓管理
COpeningManager _gOpeningManager;   // 首单开仓管理
CTrailingManager _gTrailingManager; // 尾随止损管理

//+------------------------------------------------------------------+
//|                          EA 初始化                               |
//+------------------------------------------------------------------+
int OnInit()
{

    // 1. 初始化配置
    if (!_gConfig.Init())
    {
        _gLogger.LogFatal("配置初始化失败！");
        return INIT_FAILED;
    }

    // 2. 初始化全局日志器
    _gLogger.Enable(true);
    _gLogger.SetModuleName("主控");
    _gLogger.SetLogLevel(_gConfig.LogLevel);
    _gLogger.LogInfo("========== ITS_FRT_V1.0 启动 ==========");

    // 3. 初始化全局上下文
    if (!_gContext.Init(&_gConfig))
    {
        _gLogger.LogFatal("上下文初始化失败！");
        return INIT_FAILED;
    }

    // 4. 初始化交易 API
    if (!_gTradeApi.Init(&_gContext))
    {
        _gLogger.LogFatal("交易 API 初始化失败！");
        return INIT_FAILED;
    }

    // 5. 初始化风险控制器
    if (!_gRiskController.Init(&_gContext))
    {
        _gLogger.LogFatal("风险控制器初始化失败！");
        return INIT_FAILED;
    }

    // 6. 初始化业务管理器
    if (!_gTradingManager.Init(&_gContext, &_gTradeApi, &_gRiskController))
    {
        _gLogger.LogFatal("熔断管理器初始化失败！");
        return INIT_FAILED;
    }

    if (!_gClosingManager.Init(&_gContext, &_gTradeApi))
    {
        _gLogger.LogFatal("定时清仓管理器初始化失败！");
        return INIT_FAILED;
    }

    if (!_gOpeningManager.Init(&_gContext, &_gTradeApi, &_gRiskController))
    {
        _gLogger.LogFatal("开仓管理器初始化失败！");
        return INIT_FAILED;
    }

    if (!_gTrailingManager.Init(&_gContext, &_gTradeApi))
    {
        _gLogger.LogFatal("尾随止损管理器初始化失败！");
        return INIT_FAILED;
    }

    _gLogger.LogInfo("========== 初始化完成 ==========");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//|                          EA 反初始化                             |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    _gLogger.LogInfo(StringFormat("EA 停止，原因代码：%d", reason));
}

//+------------------------------------------------------------------+
//|                          Tick 处理                               |
//+------------------------------------------------------------------+
void OnTick()
{

    // 1. 跳过不活跃 Tick（节流）
    if (!IsNewBar() && !IsNewPrice())
        return;

    // 2. 刷新上下文状态
    if (!_gContext.Refresh())
    {
        _gLogger.LogError("上下文刷新失败，跳过本 Tick");
        return;
    }

    // 3. 熔断检查与终止清仓
    _gTradingManager.Process();

    // 4. 定时清仓管理
    _gClosingManager.Process();

    // 5. 尾随止损管理
    _gTrailingManager.Process();

    // 6. 空仓时执行开仓逻辑
    _gOpeningManager.Process();
}

//+------------------------------------------------------------------+
//| 是否出现新的K线
//+------------------------------------------------------------------+
bool IsNewBar()
{
    static datetime lastBarTime = 0;
    datetime time = iTime(_gConfig.Symbol, _gConfig.TradeTimeframe, 0);
    if (time != 0 && time != lastBarTime)
    {
        lastBarTime = time;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| 是否出现新的价格变动
//+------------------------------------------------------------------+
bool IsNewPrice()
{
    static double lastBid = 0;
    double bid = SymbolInfoDouble(_gConfig.Symbol, SYMBOL_BID);
    if (MathAbs(bid - lastBid) >= SymbolInfoDouble(_gConfig.Symbol, SYMBOL_POINT))
    {
        lastBid = bid;
        return true;
    }
    return false;
}
//+------------------------------------------------------------------+
