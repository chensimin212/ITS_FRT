#property strict
#ifndef CONTROLLED_MARTINGALE_CORE_ENUMS_MQH
#define CONTROLLED_MARTINGALE_CORE_ENUMS_MQH

//----------------------------------------------------------------
// 枚举：日志等级
//----------------------------------------------------------------
enum E_LOG_LEVEL {
    LOG_DEBUG = 0, // DEBUG:调试
    LOG_INFO = 1,  // INFO:信息
    LOG_WARN = 2,  // WARN:警告
    LOG_ERROR = 3, // ERROR:错误
    LOG_FATAL = 4  // FATAL:致命
};

//----------------------------------------------------------------
// 枚举：交易状态（由 CTradingState 维护，取值按严格程度递增）
//   NORMAL 之外一律禁止开仓；LIQUIDATING 与 TERMINATED 还需平掉既有仓位。
//   递增序保证状态只升不降，写侧一律用 >= 比较守卫。
//----------------------------------------------------------------
enum E_TRADING_STATE {
    TRADING_NORMAL = 0,  // NORMAL:正常：允许新增仓位
    TRADING_PAUSED,      // PAUSED:暂停：到期自动恢复，既有仓位照常管理
    TRADING_LIQUIDATING, // LIQUIDATING:清仓：禁止开仓并平掉全部仓位，到期自动恢复
    TRADING_TERMINATED   // TERMINATED:终止：禁止开仓并平掉全部仓位，需人工重启 EA
};

//----------------------------------------------------------------
// 枚举：交易方向
//----------------------------------------------------------------
enum E_ORDER_SIDE {
    ORDER_SIDE_NONE = 0, // NONE:无交易方向，表示方向未确定或条件不成立
    ORDER_SIDE_BUY = 1,  // BUY:买入方向，对应多头仓位或看涨信号
    ORDER_SIDE_SELL = -1 // SELL:卖出方向，对应空头仓位或看跌信号
};

//----------------------------------------------------------------
// 枚举：开仓动作
//----------------------------------------------------------------
enum E_ENTRY_ACTION {
    ENTRY_ACTION_NONE = 0,
    ENTRY_ACTION_INDICATOR, // 首单开仓（市场信号 / 时间保底信号）
    ENTRY_ACTION_ADD,
    ENTRY_ACTION_RESCUE
};

#endif
