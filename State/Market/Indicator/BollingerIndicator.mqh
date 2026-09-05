#property strict
#ifndef CONTROLLED_MARTINGALE_STATE_MARKET_INDICATOR_BOLLINGER_MQH
#define CONTROLLED_MARTINGALE_STATE_MARKET_INDICATOR_BOLLINGER_MQH

#include "../../../Model/MarketAnalysis.mqh"

//--------------------------------------------------------------------
// CBollingerIndicator - 独占Boll句柄，提供三轨、带宽与带宽基线比率事实
//--------------------------------------------------------------------
class CBollingerIndicator {
private:
    string _symbol;             // 固定绑定的交易品种
    ENUM_TIMEFRAMES _timeframe; // 固定绑定的指标周期
    int _baselineBars;          // Boll带宽中位数基线根数
    int _handle;                // 本实例独占的Boll句柄

public:
    //--------------------------------------------------------------------
    // 构造 Boll 组件并将指标句柄初始化为无效状态。
    //--------------------------------------------------------------------
    CBollingerIndicator() {
        _symbol = "";
        _timeframe = PERIOD_CURRENT;
        _baselineBars = 0;
        _handle = INVALID_HANDLE;
    }

    //--------------------------------------------------------------------
    // 析构时释放当前周期独占的 Boll 指标句柄。
    //--------------------------------------------------------------------
    ~CBollingerIndicator() {
        if (_handle != INVALID_HANDLE) IndicatorRelease(_handle);
    }

    //--------------------------------------------------------------------
    // 创建指定品种和周期的 Boll 句柄并保存带宽基线窗口。
    //--------------------------------------------------------------------
    bool Init(const string symbol, const ENUM_TIMEFRAMES timeframe, const int period, const double deviation, const int baselineBars) {
        if (symbol == "" || timeframe == PERIOD_CURRENT || period < 1 || deviation <= 0 || baselineBars < 1) return false;

        if (_handle != INVALID_HANDLE) IndicatorRelease(_handle);

        _symbol = symbol;
        _timeframe = timeframe;
        _baselineBars = baselineBars;
        _handle = iBands(symbol, timeframe, period, 0, deviation, PRICE_CLOSE);

        return _handle != INVALID_HANDLE;
    }

    //--------------------------------------------------------------------
    // 读取已收K轨道值，并计算当前带宽及其相对基线比率。
    //--------------------------------------------------------------------
    bool Refresh(SBollingerFacts &facts) {
        double middle[], upper[], lower[];
        ArraySetAsSeries(middle, true);
        ArraySetAsSeries(upper, true);
        ArraySetAsSeries(lower, true);

        if (CopyBuffer(_handle, 0, 1, _baselineBars, middle) != _baselineBars ||
            CopyBuffer(_handle, 1, 1, _baselineBars, upper) != _baselineBars ||
            CopyBuffer(_handle, 2, 1, _baselineBars, lower) != _baselineBars) {
            return false;
        }

        datetime barTime = iTime(_symbol, _timeframe, 1);
        if (barTime <= 0) return false;

        double widths[];
        ArrayResize(widths, _baselineBars);
        for (int i = 0; i < _baselineBars; i++) {
            widths[i] = upper[i] - lower[i];
        }

        double sorted[];
        ArrayCopy(sorted, widths);
        // 数组已按基线根数复制且非空，此处排序不会失败，忽略返回值。
        ArraySort(sorted);
        double median = (_baselineBars % 2 == 1 ? sorted[_baselineBars / 2] : (sorted[_baselineBars / 2 - 1] + sorted[_baselineBars / 2]) * 0.5);
        if (median <= 0) return false;

        SBollingerFacts next;
        next.BarTime = barTime;
        next.Upper = upper[0];
        next.Middle = middle[0];
        next.Lower = lower[0];
        next.Width = widths[0];
        next.WidthMedian = median;
        next.WidthRatio = widths[0] / median;
        facts = next;

        return true;
    }
};

#endif
