#ifndef CONTROLLED_MARTINGALE_MODEL_POSITIONSNAPSHOT_MQH
#define CONTROLLED_MARTINGALE_MODEL_POSITIONSNAPSHOT_MQH

#property strict

#include <Object.mqh>

//--------------------------------------------------------------------
// CPositionSnapshot - 仓位快照
//--------------------------------------------------------------------
class CPositionSnapshot : public CObject {
public:
    ulong Ticket;           // 单号
    string Symbol;          // 品种
    long Magic;             // 幻数
    E_ORDER_SIDE Side;      // 方向
    double Volume;          // 手数
    double OpenPrice;       // 开仓价
    double StopLoss;        // 止损价
    double TakeProfit;      // 止盈价
    double Profit;          // 盈利
    datetime OpenTime;      // 开仓时间
    long OpenTimeMsc;       // 开仓时间（毫秒，用于稳定识别最新仓位）
    string Comment;         // 备注（识别进场E/加仓A/补仓R）
    double Swap;            // 库存费
    double Commission;      // 按持仓手数预留的双边总佣金（负值）
    double LockedNetProfit; // 按当前止损退出时该笔持仓的锁定净收益；无止损时为0
    bool LegLocked;         // 当前止损退出净收益是否严格大于0

public:
    //--------------------------------------------------------------------
    // 构造持仓快照并清空全部平台持仓事实。
    //--------------------------------------------------------------------
    CPositionSnapshot() {
    }
    //--------------------------------------------------------------------
    // 析构持仓快照；仅保存值类型事实。
    //--------------------------------------------------------------------
    ~CPositionSnapshot() {
    }
};

#endif
