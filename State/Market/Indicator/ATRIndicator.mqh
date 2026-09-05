#property strict
#ifndef CONTROLLED_MARTINGALE_STATE_MARKET_INDICATOR_ATRINDICATOR_MQH
#define CONTROLLED_MARTINGALE_STATE_MARKET_INDICATOR_ATRINDICATOR_MQH

#include "../../../Model/MarketAnalysis.mqh"

//--------------------------------------------------------------------
// CATRIndicator - 独占ATR句柄，提供当期值、基线中位数与比率事实
//--------------------------------------------------------------------
class CATRIndicator {
private:
    string _symbol;             // 固定绑定的交易品种
    ENUM_TIMEFRAMES _timeframe; // 固定绑定的指标周期
    int _baselineBars;          // ATR中位数基线根数
    int _handle;                // 本实例独占的ATR句柄

public:
    //--------------------------------------------------------------------
    // 构造 ATR 组件并将指标句柄初始化为无效状态。
    //--------------------------------------------------------------------
    CATRIndicator() {
        _symbol = "";
        _timeframe = PERIOD_CURRENT;
        _baselineBars = 0;
        _handle = INVALID_HANDLE;
    }

    //--------------------------------------------------------------------
    // 析构时释放当前周期独占的 ATR 指标句柄。
    //--------------------------------------------------------------------
    ~CATRIndicator() {
        if (_handle != INVALID_HANDLE) IndicatorRelease(_handle);
    }

    //--------------------------------------------------------------------
    // 创建指定品种和周期的 ATR 句柄并保存基线窗口。
    //--------------------------------------------------------------------
    bool Init(const string symbol, const ENUM_TIMEFRAMES timeframe, const int period, const int baselineBars) {
        if (symbol == "" || timeframe == PERIOD_CURRENT || period < 1 || baselineBars < 1) return false;

        if (_handle != INVALID_HANDLE) IndicatorRelease(_handle);

        _symbol = symbol;
        _timeframe = timeframe;
        _baselineBars = baselineBars;
        _handle = iATR(symbol, timeframe, period);

        return _handle != INVALID_HANDLE;
    }

    //--------------------------------------------------------------------
    // 读取已收K ATR，并计算前值、基线中位数和相对基线比率。
    //--------------------------------------------------------------------
    bool Refresh(SATRFacts &facts) {
        int count = MathMax(_baselineBars, 2);

        double values[];
        ArraySetAsSeries(values, true);

        if (CopyBuffer(_handle, 0, 1, count, values) != count) return false;

        datetime barTime = iTime(_symbol, _timeframe, 1);
        if (barTime <= 0 || values[0] <= 0) return false;

        double sorted[];
        ArrayResize(sorted, _baselineBars);
        for (int i = 0; i < _baselineBars; i++) {
            sorted[i] = values[i];
        }

        // 数组已按基线根数 Resize 且非空，此处排序不会失败，忽略返回值。
        ArraySort(sorted);
        double median = (_baselineBars % 2 == 1 ? sorted[_baselineBars / 2] : (sorted[_baselineBars / 2 - 1] + sorted[_baselineBars / 2]) * 0.5);
        if (median <= 0) return false;

        SATRFacts next;
        next.BarTime = barTime;
        next.Value = values[0];
        next.Previous = values[1];
        next.Median = median;
        next.Ratio = values[0] / median;
        facts = next;

        return true;
    }
};

#endif
