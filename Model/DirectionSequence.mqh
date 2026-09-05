#property strict
#ifndef CONTROLLED_MARTINGALE_MODEL_DIRECTIONSEQUENCE_MQH
#define CONTROLLED_MARTINGALE_MODEL_DIRECTIONSEQUENCE_MQH

#include <Object.mqh>

//--------------------------------------------------------------------
// CDirectionSequence - 单方向序列状态
//--------------------------------------------------------------------
class CDirectionSequence : public CObject {
public:
    E_ORDER_SIDE Side;         // 当前序列所属订单方向
    int PositionCount;         // 当前方向持仓数量
    int RescueCount;           // 当前方向注释标记为 R 的亏损补仓数量
    int AddCount;              // 当前方向注释标记为 A 的盈利加仓数量
    double TotalVolume;        // 当前方向实际持仓总手数
    double TotalNetProfit;     // 当前方向组合净盈亏（含库存费与佣金）
    bool AllProtected;         // 当前方向每笔持仓均有有效保护价；空仓为 false
    double LockedNetProfit;    // 按当前保护价退出的锁定净收益合计（账户货币）
    bool AllLegLocked;         // 当前方向每笔按自身保护价退出均净收益为正；空仓为 false
    double ProtectiveStopLoss; // 当前方向最保守保护价（多=最小SL，空=最大SL）；空仓或存在无保护仓位为 0
    ulong LatestTicket;        // 当前方向最新持仓的单号
    double LatestOpenPrice;    // 当前方向最新持仓的开仓价
    datetime LatestOpenTime;   // 当前方向最新持仓的开仓时间
    long LatestOpenTimeMsc;    // 当前方向最新持仓的毫秒开仓时间
    bool HasLosingLeg;                 // 当前方向是否存在按价格判断的亏损仓位
    ulong LeastLosingTicket;           // 亏损距离最小仓位单号
    double LeastLosingOpenPrice;       // 亏损距离最小仓位开仓价
    double LeastLosingAdverseDistance; // 亏损距离最小仓位逆向价格距离
    long LeastLosingOpenTimeMsc;       // 亏损距离最小仓位开仓毫秒时间

    // L3新增：锁盈统计
    int LockedCount;      // 已锁盈仓位数量
    double LockRatio;     // 锁盈比例（LockedCount / PositionCount）

public:
    //--------------------------------------------------------------------
    // 构造方向序列并初始化为无方向空仓状态。
    //--------------------------------------------------------------------
    CDirectionSequence() {
    }
    //--------------------------------------------------------------------
    // 析构方向序列；仅保存值类型聚合事实。
    //--------------------------------------------------------------------
    ~CDirectionSequence() {
    }

    //--------------------------------------------------------------------
    // 清空方向序列的全部聚合结果，并设置新一轮统计方向
    //--------------------------------------------------------------------
    void Reset(E_ORDER_SIDE side) {
        Side = side;              // 设置本轮统计方向
        PositionCount = 0;        // 清空持仓数量
        RescueCount = 0;          // 清空亏损补仓数量
        AddCount = 0;             // 清空盈利加仓数量
        TotalVolume = 0.0;        // 清空实际持仓总手数
        TotalNetProfit = 0.0;     // 清空组合净盈亏
        AllProtected = false;     // 空仓不构成整体锁盈
        LockedNetProfit = 0.0;    // 清空锁定净收益
        AllLegLocked = false;     // 空仓不构成逐笔锁盈
        ProtectiveStopLoss = 0.0; // 清空最保守保护价
        LatestTicket = 0;         // 清空最新持仓单号
        LatestOpenPrice = 0.0;    // 清空最新持仓开仓价
        LatestOpenTime = 0;       // 清空最新持仓开仓时间
        LatestOpenTimeMsc = 0;    // 清空最新持仓毫秒开仓时间
        HasLosingLeg = false;
        LeastLosingTicket = 0;
        LeastLosingOpenPrice = 0.0;
        LeastLosingAdverseDistance = 0.0;
        LeastLosingOpenTimeMsc = 0;
        LockedCount = 0;           // L3新增：初始化锁盈计数
        LockRatio = 0.0;           // L3新增：初始化锁盈比例
    }
};

#endif
