#property strict
#ifndef CONTROLLED_MARTINGALE_STATE_MARKET_INDICATOR_RSIINDICATOR_MQH
#define CONTROLLED_MARTINGALE_STATE_MARKET_INDICATOR_RSIINDICATOR_MQH

#include "../../../Model/MarketAnalysis.mqh"

//--------------------------------------------------------------------
// CRSIIndicator - 独占RSI句柄，提供当期值与窗口变化量事实
//--------------------------------------------------------------------
class CRSIIndicator {
private:
    string _symbol;             // 固定绑定的交易品种
    ENUM_TIMEFRAMES _timeframe; // 固定绑定的指标周期
    int _slopeBars;             // RSI变化量回看根数
    int _handle;                // 本实例独占的RSI句柄

public:
    //--------------------------------------------------------------------
    // 构造 RSI 组件并将指标句柄初始化为无效状态。
    //--------------------------------------------------------------------
    CRSIIndicator() {
        _symbol = "";
        _timeframe = PERIOD_CURRENT;
        _slopeBars = 0;
        _handle = INVALID_HANDLE;
    }

    //--------------------------------------------------------------------
    // 析构时释放当前周期独占的 RSI 指标句柄。
    //--------------------------------------------------------------------
    ~CRSIIndicator() {
        if (_handle != INVALID_HANDLE) IndicatorRelease(_handle);
    }

    //--------------------------------------------------------------------
    // 创建指定品种和周期的 RSI 句柄并保存变化窗口。
    //--------------------------------------------------------------------
    bool Init(const string symbol, const ENUM_TIMEFRAMES timeframe, const int period, const int slopeBars) {
        if (symbol == "" || timeframe == PERIOD_CURRENT || period < 1 || slopeBars < 1) return false;

        if (_handle != INVALID_HANDLE) IndicatorRelease(_handle);

        _symbol = symbol;
        _timeframe = timeframe;
        _slopeBars = slopeBars;
        _handle = iRSI(symbol, timeframe, period, PRICE_CLOSE);

        return _handle != INVALID_HANDLE;
    }

    //--------------------------------------------------------------------
    // 读取已收K RSI 当前值、前值和窗口变化并发布事实。
    //--------------------------------------------------------------------
    bool Refresh(SRSIFacts &facts) {
        int count = _slopeBars + 1;
        double values[];
        ArraySetAsSeries(values, true);
        if (CopyBuffer(_handle, 0, 1, count, values) != count) {
            return false;
        }

        datetime barTime = iTime(_symbol, _timeframe, 1);
        if (barTime <= 0) return false;

        SRSIFacts next;
        next.BarTime = barTime;
        next.Value = values[0];
        next.Change = values[0] - values[_slopeBars];
        facts = next;

        return true;
    }
};

#endif
