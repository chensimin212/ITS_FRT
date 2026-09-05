#ifndef CONTROLLED_MARTINGALE_STATE_SYMBOLSTATE_MQH
#define CONTROLLED_MARTINGALE_STATE_SYMBOLSTATE_MQH

#property strict

#include <Object.mqh>
#include "../Config/BaseConfig.mqh"
#include "../Core/Logger.mqh"

//--------------------------------------------------------------------
// CSymbolState - 交易品种信息状态
//--------------------------------------------------------------------
class CSymbolState : public CObject {
private:
    CLogger _logger;      // 品种规格与实时行情刷新诊断日志器
    CBaseConfig *_config; // 目标品种、点差和交易规则配置
    bool _initialized;    // 是否已初始化

public:
    string Symbol;     // 交易品种
    int Digits;        // 小数精度
    double MinLot;     // 最小可交易手数
    double MaxLot;     // 最大可交易手数
    double LotLimit;   // 手数限制
    double LotStep;    // 手数步进值
    double TickValue;  // 每一个最小变动（1 Tick）对应的账户货币价值
    double TickSize;   // 该交易品种价格最小变动单位（最小跳动）
    double Point;      // 当前交易品种的最小报价变动单位（Point）
    double PointValue; // 点值
    long StopsLevel;   // 经纪商最小止损/止盈距离（点数，0=无限制）
    long FreezeLevel;  // 经纪商冻结距离（点数，0=无限制）
    double Bid;        // 买价
    double Ask;        // 卖价
    double Spread;     // 当前点差（点数）

public:
    CSymbolState();  // 构造并清空品种交易规格与报价状态
    ~CSymbolState(); // 析构品种状态对象

    bool Init(CBaseConfig *config);                  // 初始化
    bool Refresh();                                  // 刷新
    double NormalizeVolumeDown(const double volume); // 按品种手数规格向下归一化，非法时返回 0
};

//--------------------------------------------------------------------
// 构造函数
//--------------------------------------------------------------------
CSymbolState::CSymbolState() {
    _config = NULL;
    _initialized = false;
}

//--------------------------------------------------------------------
// 析构函数
//--------------------------------------------------------------------
CSymbolState::~CSymbolState() {
}

//--------------------------------------------------------------------
// 初始化
//--------------------------------------------------------------------
bool CSymbolState::Init(CBaseConfig *config) {
    _config = config;

    // 日志设置：
    _logger.Enable(true);
    _logger.SetModuleName("品种状态");
    _logger.SetLogLevel(_config.LogLevel);

    // 防止切换时间周期时，重新初始化
    if (_initialized) return true;

    // 交易品种信息：
    Symbol = _config.Symbol;
    Digits = (int)SymbolInfoInteger(Symbol, SYMBOL_DIGITS);
    MinLot = SymbolInfoDouble(Symbol, SYMBOL_VOLUME_MIN);
    MaxLot = SymbolInfoDouble(Symbol, SYMBOL_VOLUME_MAX);
    LotLimit = SymbolInfoDouble(Symbol, SYMBOL_VOLUME_LIMIT);
    LotStep = SymbolInfoDouble(Symbol, SYMBOL_VOLUME_STEP);
    TickValue = SymbolInfoDouble(Symbol, SYMBOL_TRADE_TICK_VALUE);
    TickSize = SymbolInfoDouble(Symbol, SYMBOL_TRADE_TICK_SIZE);
    Point = SymbolInfoDouble(Symbol, SYMBOL_POINT);
    StopsLevel = SymbolInfoInteger(Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    FreezeLevel = SymbolInfoInteger(Symbol, SYMBOL_TRADE_FREEZE_LEVEL);

    // 交易品种信息：点值
    if (TickValue <= 0) return _logger.LogError4Boolean("交易品种信息错误(TICK_VALUE)");
    if (TickSize <= 0) return _logger.LogError4Boolean("交易品种信息错误(TICK_SIZE)");
    if (Point <= 0) return _logger.LogError4Boolean("交易品种信息错误(POINT)");
    PointValue = TickValue * (Point / TickSize);

    // 初始化成功：
    _initialized = true;
    return true;
}

//--------------------------------------------------------------------
// 刷新
//--------------------------------------------------------------------
bool CSymbolState::Refresh() {
    Bid = SymbolInfoDouble(Symbol, SYMBOL_BID);
    Ask = SymbolInfoDouble(Symbol, SYMBOL_ASK);
    Spread = (Point > 0 ? (Ask - Bid) / Point : 0.0);
    return true;
}

//--------------------------------------------------------------------
// 手数向下归一化：非法规格、低于最小手数或超过单笔最大手数时返回 0
//--------------------------------------------------------------------
double CSymbolState::NormalizeVolumeDown(const double volume) {
    if (volume <= 0 || MinLot <= 0 || MaxLot <= 0 || LotStep <= 0) return 0.0;
    if (volume < MinLot || volume > MaxLot) return 0.0;

    double steps = MathFloor((volume + LotStep * 1e-9) / LotStep);
    double normalized = steps * LotStep;
    if (normalized < MinLot || normalized > MaxLot) return 0.0;

    int digits = 0;
    double scaled = LotStep;
    while (digits < 8 && MathAbs(scaled - MathRound(scaled)) > 1e-9) {
        scaled *= 10.0;
        digits++;
    }
    return NormalizeDouble(normalized, digits);
}

#endif
