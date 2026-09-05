#property strict
#ifndef CONTROLLED_MARTINGALE_STATE_MARKET_INDICATOR_ADXINDICATOR_MQH
#define CONTROLLED_MARTINGALE_STATE_MARKET_INDICATOR_ADXINDICATOR_MQH

#include "../../../Model/MarketAnalysis.mqh"

//--------------------------------------------------------------------
// CADXIndicator - 独占ADX句柄，提供强度、窗口变化量与正负DI事实
//--------------------------------------------------------------------
class CADXIndicator {
private:
    string _symbol;             // 固定绑定的交易品种
    ENUM_TIMEFRAMES _timeframe; // 固定绑定的指标周期
    int _slopeBars;             // ADX变化量回看根数
    int _handle;                // 本实例独占的ADX句柄

public:
    //--------------------------------------------------------------------
    // 构造 ADX 组件并将指标句柄初始化为无效状态。
    //--------------------------------------------------------------------
    CADXIndicator() {
        _symbol = "";
        _timeframe = PERIOD_CURRENT;
        _slopeBars = 0;
        _handle = INVALID_HANDLE;
    }

    //--------------------------------------------------------------------
    // 析构时释放当前周期独占的 ADX 指标句柄。
    //--------------------------------------------------------------------
    ~CADXIndicator() {
        if (_handle != INVALID_HANDLE) IndicatorRelease(_handle);
    }

    //--------------------------------------------------------------------
    // 创建指定品种和周期的 ADX 句柄并保存变化窗口。
    //--------------------------------------------------------------------
    bool Init(const string symbol, const ENUM_TIMEFRAMES timeframe, const int period, const int slopeBars) {
        if (symbol == "" || timeframe == PERIOD_CURRENT || period < 1 || slopeBars < 1) return false;

        if (_handle != INVALID_HANDLE) IndicatorRelease(_handle);

        _symbol = symbol;
        _timeframe = timeframe;
        _slopeBars = slopeBars;
        _handle = iADX(symbol, timeframe, period);

        return _handle != INVALID_HANDLE;
    }

    //--------------------------------------------------------------------
    // 读取同一根已收K的 ADX、DI 与窗口变化值并发布事实。
    //--------------------------------------------------------------------
    bool Refresh(SADXFacts &facts) {
        int count = _slopeBars + 1;
        double adx[], plusDi[], minusDi[];
        ArraySetAsSeries(adx, true);
        ArraySetAsSeries(plusDi, true);
        ArraySetAsSeries(minusDi, true);

        // 严格校验缓冲区读取成功，防止指标句柄更新不同步时拼接跨K线数据。
        if (CopyBuffer(_handle, 0, 1, count, adx) != count ||
            CopyBuffer(_handle, 1, 1, 1, plusDi) != 1 ||
            CopyBuffer(_handle, 2, 1, 1, minusDi) != 1) {
            return false;
        }

        datetime barTime = iTime(_symbol, _timeframe, 1);
        if (barTime <= 0) return false;

        SADXFacts next;
        next.BarTime = barTime;
        next.ADX = adx[0];
        next.Change = adx[0] - adx[_slopeBars];
        next.PlusDI = plusDi[0];
        next.MinusDI = minusDi[0];
        facts = next;
        return true;
    }
};

#endif
