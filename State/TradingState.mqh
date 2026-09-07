#ifndef CONTROLLED_MARTINGALE_STATE_TRADINGSTATE_MQH
#define CONTROLLED_MARTINGALE_STATE_TRADINGSTATE_MQH

#property strict

#include <Object.mqh>
#include "../Config/BaseConfig.mqh"
#include "../Core/Consts.mqh"
#include "../Core/Enums.mqh"
#include "../Core/Logger.mqh"

//--------------------------------------------------------------------
// CTradingState - 交易状态，由 E_TRADING_STATE 单一字段描述，取值按严格程度递增
//
//   四个写侧方法（状态只升不降，重复调用幂等）：
//     PauseEntry(原因, 恢复时间)  — 仅禁止开仓，既有仓位照常管理
//                                   恢复时间传 0 表示无定时恢复，须由 ResumeEntry(true) 显式解除
//     Liquidating(原因, 结束时间) — 禁止开仓并清仓
//     Terminate(原因)             — 禁止开仓并清仓，需人工重启 EA
//     ResumeEntry(是否手动)       — 回到正常态；自动恢复须已到恢复时间
//
//   读侧按行为提问，无需感知严格程度阶梯：
//     IsEntryBlocked()       — 禁止开仓
//     IsTerminated()         — 已终止，等待人工重启
//     IsPausedIndefinitely() — 暂停中且无定时恢复计划，等待调用方确认条件已消失
//
//   自动恢复与每日提醒均由 CContext::Refresh() 每轮调用触发
//--------------------------------------------------------------------
class CTradingState : public CObject {
private:
    CLogger _logger;      // 状态变更与每日提醒日志器
    CBaseConfig *_config; // 日志级别等基础配置

    E_TRADING_STATE _state; // 当前状态，唯一真相源
    string _reason;         // 当前非正常态的原因
    datetime _stopTime;     // 进入非正常态的时间
    datetime _resumeTime;   // 计划恢复时间；终止时为 STOP_RESUME_SENTINEL 使自动恢复永不触发
    datetime _lastLogDate;  // 已提醒过的日期零点，同日不重复打印

    datetime TodayDate();                                                                   // 当前服务器日期的零点
    string StateName(const E_TRADING_STATE state);                                          // 状态中文名，仅用于日志
    void EnterState(const E_TRADING_STATE state, const string reason, datetime resumeTime); // 写入非正常态的公共处理

public:
    CTradingState(); // 构造交易状态
    ~CTradingState() {
    }

    bool Init(CBaseConfig *config); // 注入配置

    // —— 读侧 ——
    E_TRADING_STATE State();     // 当前状态
    bool IsEntryBlocked();       // 禁止开仓
    bool IsTerminated();         // 已终止，等待人工重启
    bool IsPausedIndefinitely(); // 暂停中且无定时恢复计划

    // —— 写侧 ——
    void PauseEntry(const string reason, datetime resumeTime);  // 暂停开仓
    void Liquidating(const string reason, datetime finishTime); // 设置清仓
    void Terminate(const string reason);                        // 终止交易
    void ResumeEntry(const bool manual);                        // 恢复开仓

    // —— 日志 ——
    void PrintStatusLog(); // 非正常态期间每日打印一次提醒
};

//--------------------------------------------------------------------
// 构造函数
//--------------------------------------------------------------------
CTradingState::CTradingState() {
    _config = NULL;
    _state = TRADING_NORMAL;
    _reason = "";
    _stopTime = 0;
    _resumeTime = 0;
    _lastLogDate = 0;
}

//--------------------------------------------------------------------
// 初始化
//--------------------------------------------------------------------
bool CTradingState::Init(CBaseConfig *config) {
    _config = config;
    _logger.Enable(true);
    _logger.SetModuleName("交易状态");
    _logger.SetLogLevel(_config.LogLevel);
    return true;
}

//--------------------------------------------------------------------
// 当前服务器日期的零点，用于每日提醒去重
//--------------------------------------------------------------------
datetime CTradingState::TodayDate() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    return StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
}

//--------------------------------------------------------------------
// 状态中文名，仅用于日志
//--------------------------------------------------------------------
string CTradingState::StateName(const E_TRADING_STATE state) {
    switch (state) {
    case TRADING_PAUSED:
        return "暂停开仓";
    case TRADING_LIQUIDATING:
        return "清仓";
    case TRADING_TERMINATED:
        return "终止交易";
    }
    return "正常开仓";
}

//--------------------------------------------------------------------
// 写入非正常态：记录原因、起始时间与恢复时间
//   本次变更已产生一条日志，故占用当日提醒额度，避免同日重复输出同一状态
//--------------------------------------------------------------------
void CTradingState::EnterState(const E_TRADING_STATE state, const string reason, datetime resumeTime) {
    _state = state;
    _reason = reason;
    _stopTime = TimeCurrent();
    _resumeTime = resumeTime;
    _lastLogDate = TodayDate();
}

//--------------------------------------------------------------------
// 当前状态
//--------------------------------------------------------------------
E_TRADING_STATE CTradingState::State() {
    return _state;
}

//--------------------------------------------------------------------
// 是否禁止开仓：暂停、清仓与终止均返回 true
//--------------------------------------------------------------------
bool CTradingState::IsEntryBlocked() {
    return _state != TRADING_NORMAL;
}

//--------------------------------------------------------------------
// 是否已终止，等待人工重启
//--------------------------------------------------------------------
bool CTradingState::IsTerminated() {
    return _state == TRADING_TERMINATED;
}

//--------------------------------------------------------------------
// 是否暂停中且无定时恢复计划：条件何时消失未知，由调用方确认后手动恢复
//--------------------------------------------------------------------
bool CTradingState::IsPausedIndefinitely() {
    return _state == TRADING_PAUSED && _resumeTime == 0;
}

//--------------------------------------------------------------------
// 暂停开仓：既有仓位照常管理
//   恢复时间 >0 时到期由 ResumeEntry(false) 自动恢复；传 0 表示恢复时机未知，
//   须由调用方确认暂停条件已消失后调 ResumeEntry(true)。
//   已处于同级或更严格状态时不降级，避免顶掉清仓、终止或更早的恢复计划。
//--------------------------------------------------------------------
void CTradingState::PauseEntry(const string reason, datetime resumeTime) {
    if (_state >= TRADING_PAUSED) return;

    EnterState(TRADING_PAUSED, reason, resumeTime);
    string resumeText = (resumeTime > 0 ? TimeToString(resumeTime) : "待条件恢复");
    string startTimeText = TimeToString(_stopTime);
    _logger.LogWarn(StringFormat("暂停开仓：%s | 开始时间：%s | 预计恢复：%s",
                                 reason, startTimeText, resumeText));
}

//--------------------------------------------------------------------
// 设置清仓：禁止开仓并平掉既有仓位，到期由 ResumeEntry(false) 自动恢复
//   由暂停升级而来时重置起始时间与恢复时间
//--------------------------------------------------------------------
void CTradingState::Liquidating(const string reason, datetime finishTime) {
    if (_state >= TRADING_LIQUIDATING) return;

    EnterState(TRADING_LIQUIDATING, reason, finishTime);
    string startTimeText = TimeToString(_stopTime);
    string finishTimeText = TimeToString(_resumeTime);
    _logger.LogWarn(StringFormat("设置清仓：%s | 开始时间：%s | 预计结束：%s",
                                 reason, startTimeText, finishTimeText));
}

//--------------------------------------------------------------------
// 终止交易：禁止开仓并平掉既有仓位；恢复时间置哨兵值使自动恢复永不触发
//   优先级最高，可由任何状态升级而来
//--------------------------------------------------------------------
void CTradingState::Terminate(const string reason) {
    if (_state >= TRADING_TERMINATED) return;

    EnterState(TRADING_TERMINATED, reason, STOP_RESUME_SENTINEL);
    string stopTimeText = TimeToString(_stopTime);
    _logger.LogWarn(StringFormat("终止交易：%s | 终止时间：%s | 需人工重启EA",
                                 reason, stopTimeText));
}

//--------------------------------------------------------------------
// 恢复开仓：manual=true 无条件恢复；manual=false 仅在已到恢复时间时恢复
//   恢复时间为 0（无计划）或哨兵值（终止）时自动恢复永不触发，只能手动解除
//--------------------------------------------------------------------
void CTradingState::ResumeEntry(const bool manual) {
    if (_state == TRADING_NORMAL) return;
    if (!manual && (_resumeTime == 0 || TimeCurrent() < _resumeTime)) return;

    int durationSec = (int)(TimeCurrent() - _stopTime);
    string stateText = StateName(_state);
    _logger.LogInfo(StringFormat("恢复开仓：解除%s（%s，持续=%ds）",
                                 stateText, manual ? "条件已消失" : "已到计划恢复时间", durationSec));

    _state = TRADING_NORMAL;
    _reason = "";
    _stopTime = 0;
    _resumeTime = 0;
    _lastLogDate = 0; // 释放提醒额度，下一次进入非正常态当日仍可提醒
}

//--------------------------------------------------------------------
// 非正常态期间每日打印一次提醒，便于在长日志中定位长时间无开仓的原因
//--------------------------------------------------------------------
void CTradingState::PrintStatusLog() {
    if (_state == TRADING_NORMAL) return;

    datetime today = TodayDate();
    if (_lastLogDate == today) return;
    _lastLogDate = today;

    if (_state == TRADING_TERMINATED) {
        // 按日期差计数，避免"23:00 终止、次日 09:00 提醒"被算成 0 天
        string stopDateText = TimeToString(_stopTime, TIME_DATE);
        int days = (int)((today - StringToTime(stopDateText)) / 86400);
        string stopTimeText = TimeToString(_stopTime);
        _logger.LogWarn(StringFormat("[每日提醒] 交易已终止，等待人工重启EA | 原因：%s | 终止时间：%s | 已终止 %d 天",
                                     _reason, stopTimeText, days));
        return;
    }

    int hours = (int)((TimeCurrent() - _stopTime) / 3600);
    string resumeText = (_resumeTime > 0 ? TimeToString(_resumeTime) : "待条件恢复");
    string stateText = StateName(_state);
    string startTimeText = TimeToString(_stopTime);
    _logger.LogWarn(StringFormat("[每日提醒] %s | 原因：%s | 开始时间：%s | 已持续 %d 小时 | 预计恢复：%s",
                                 stateText, _reason, startTimeText, hours, resumeText));
}

#endif
