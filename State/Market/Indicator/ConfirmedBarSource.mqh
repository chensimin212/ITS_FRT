#property strict
#ifndef CONTROLLED_MARTINGALE_STATE_MARKET_INDICATOR_CONFIRMEDBAR_MQH
#define CONTROLLED_MARTINGALE_STATE_MARKET_INDICATOR_CONFIRMEDBAR_MQH

#include "../../../Model/MarketAnalysis.mqh"

//--------------------------------------------------------------------
// CConfirmedBarSource - 只读取已收K的开高低收价格事实，不触碰未收K
//--------------------------------------------------------------------
class CConfirmedBarSource {
private:
    string _symbol;             // 固定绑定的交易品种
    ENUM_TIMEFRAMES _timeframe; // 固定绑定的K线周期

public:
    //--------------------------------------------------------------------
    // 构造已收K数据源并初始化为空品种和周期。
    //--------------------------------------------------------------------
    CConfirmedBarSource() {
        _symbol = "";
        _timeframe = PERIOD_CURRENT;
    }

    //--------------------------------------------------------------------
    // 绑定数据源使用的品种与独立分析周期。
    //--------------------------------------------------------------------
    bool Init(const string symbol, const ENUM_TIMEFRAMES timeframe) {
        if (symbol == "" || timeframe == PERIOD_CURRENT) return false;
        _symbol = symbol;
        _timeframe = timeframe;
        return true;
    }

    //--------------------------------------------------------------------
    // 读取最近一根已收K并发布 OHLC 与开盘时间事实。
    // L4扩展：同时加载最近3根K的实体数据（用于动能衰减判定）
    //--------------------------------------------------------------------
    bool Refresh(SConfirmedBarFacts &facts) {
        MqlRates bars[];
        ArraySetAsSeries(bars, true);
        // L4修改：从1根扩展到3根（当前K + 前2根）
        if (CopyRates(_symbol, _timeframe, 1, 3, bars) < 1) {
            return false;
        }

        SConfirmedBarFacts next;
        next.BarTime = bars[0].time;
        next.Open = bars[0].open;
        next.High = bars[0].high;
        next.Low = bars[0].low;
        next.Close = bars[0].close;

        // L4新增：加载最近3根K的实体数据
        int copiedCount = ArraySize(bars);
        for (int i = 0; i < 3; i++) {
            if (i < copiedCount) {
                next.PrevBody[i] = MathAbs(bars[i].close - bars[i].open);
                next.PrevBullish[i] = (bars[i].close > bars[i].open);
            } else {
                // 不足3根时，填充0（启动期）
                next.PrevBody[i] = 0.0;
                next.PrevBullish[i] = false;
            }
        }

        facts = next;
        return true;
    }
};

#endif
