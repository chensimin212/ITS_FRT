#property strict
#ifndef CONTROLLED_MARTINGALE_STATE_MARKET_INDICATOR_EMAINDICATOR_MQH
#define CONTROLLED_MARTINGALE_STATE_MARKET_INDICATOR_EMAINDICATOR_MQH

#include "../../../Model/MarketAnalysis.mqh"

//--------------------------------------------------------------------
// CEMAIndicator - 独占快慢EMA句柄，提供EMA值与ATR标准化斜率和间距事实
//--------------------------------------------------------------------
class CEMAIndicator {
private:
    string _symbol;             // 固定绑定的交易品种
    ENUM_TIMEFRAMES _timeframe; // 固定绑定的指标周期
    int _slopeBars;             // EMA斜率回看根数
    int _fastHandle;            // 本实例独占的快速EMA句柄
    int _slowHandle;            // 本实例独占的慢速EMA句柄

public:
    //--------------------------------------------------------------------
    // 构造 EMA 组件并将快慢指标句柄初始化为无效状态。
    //--------------------------------------------------------------------
    CEMAIndicator() {
        _symbol = "";
        _timeframe = PERIOD_CURRENT;
        _slopeBars = 0;
        _fastHandle = INVALID_HANDLE;
        _slowHandle = INVALID_HANDLE;
    }

    //--------------------------------------------------------------------
    // 析构时释放当前周期独占的快慢 EMA 指标句柄。
    //--------------------------------------------------------------------
    ~CEMAIndicator() {
        if (_fastHandle != INVALID_HANDLE) IndicatorRelease(_fastHandle);
        if (_slowHandle != INVALID_HANDLE) IndicatorRelease(_slowHandle);
    }

    //--------------------------------------------------------------------
    // 创建指定品种和周期的快慢 EMA 句柄并保存斜率窗口。
    //--------------------------------------------------------------------
    bool Init(const string symbol, const ENUM_TIMEFRAMES timeframe, const int fastPeriod, const int slowPeriod, const int slopeBars) {
        if (symbol == "" || timeframe == PERIOD_CURRENT || fastPeriod < 1 || slowPeriod < 1 || slopeBars < 1) return false;

        if (_fastHandle != INVALID_HANDLE) IndicatorRelease(_fastHandle);
        if (_slowHandle != INVALID_HANDLE) IndicatorRelease(_slowHandle);

        _symbol = symbol;
        _timeframe = timeframe;
        _slopeBars = slopeBars;
        _fastHandle = iMA(symbol, timeframe, fastPeriod, 0, MODE_EMA, PRICE_CLOSE);
        _slowHandle = iMA(symbol, timeframe, slowPeriod, 0, MODE_EMA, PRICE_CLOSE);

        return _fastHandle != INVALID_HANDLE && _slowHandle != INVALID_HANDLE;
    }

    //--------------------------------------------------------------------
    // 读取已收K快慢 EMA，并将窗口变化按当前 ATR 归一化为斜率事实。
    //--------------------------------------------------------------------
    bool Refresh(const double atr, SEMAFacts &facts) {
        if (atr <= 0) return false;

        int count = _slopeBars + 1;

        double fast[], slow[];
        ArraySetAsSeries(fast, true);
        ArraySetAsSeries(slow, true);
        if (CopyBuffer(_fastHandle, 0, 1, count, fast) != count ||
            CopyBuffer(_slowHandle, 0, 1, count, slow) != count) {
            return false;
        }

        datetime barTime = iTime(_symbol, _timeframe, 1);
        if (barTime <= 0) return false;

        SEMAFacts next;
        next.BarTime = barTime;
        next.Fast = fast[0];
        next.Slow = slow[0];
        next.FastSlopeATR = (fast[0] - fast[_slopeBars]) / atr;
        next.SlowSlopeATR = (slow[0] - slow[_slopeBars]) / atr;
        next.DistanceATR = (fast[0] - slow[0]) / atr;
        facts = next;

        return true;
    }
};

#endif
