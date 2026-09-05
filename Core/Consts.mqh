#property strict
#ifndef CONTROLLED_MARTINGALE_CORE_CONSTS_MQH
#define CONTROLLED_MARTINGALE_CORE_CONSTS_MQH

//--------------------------------------------------------------------
// 系统配置
//--------------------------------------------------------------------
// 生产环境开关（调试时取消注释）
// #define USE_PRO_CONFIG

// 生产环境最低日志级别
#define PRO_MIN_LOG_LEVEL 1

// 固定模式启动净值下限（相对固定风险净值的比例）
#define FIXED_MODE_MIN_INITIAL_EQUITY_RATIO 0.95

// 尾随止损缓冲比例（极值外噪声余量 = 超幅 × 该比例）
#define TRAILING_BUFFER_RATIO 0.05

// 终止交易的恢复时间哨兵值：远超任何回测与实盘周期，等价于永不自动恢复
#define STOP_RESUME_SENTINEL D'3000.01.01'

#endif
