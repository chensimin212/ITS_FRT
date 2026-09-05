#property strict
#ifndef CONTROLLED_MARTINGALE_STATE_TIMINGTRACKER_MQH
#define CONTROLLED_MARTINGALE_STATE_TIMINGTRACKER_MQH

#include <Object.mqh>
#include "../Core/Logger.mqh"
#include "../Config/BaseConfig.mqh"

//--------------------------------------------------------------------
// CTimingTracker - 开仓时间跟踪器
//
// 职责：
// - 记录首单开仓时间
// - 判断是否应启用时间窗口保底机制
// - 跨日重置计数器
//
// 设计目标：确保"每个开盘日都有订单"，避免长时间空仓
//--------------------------------------------------------------------
class CTimingTracker : public CObject {
private:
    CLogger _logger;
    CBaseConfig *_config;
    datetime _lastOpeningTime;    // 上次首单开仓时间
    int _todayOpeningCount;       // 今日首单次数
    datetime _todayDate;          // 当前日期（用于跨日重置）

public:
    CTimingTracker();
    ~CTimingTracker() {}

    bool Init(CBaseConfig *config);
    void RecordOpening(datetime time);           // 记录开仓
    bool ShouldEnableMinimalEntry();             // 是否启用保底机制
    int GetHoursSinceLastOpening();              // 距上次开仓小时数
    int GetTodayOpeningCount() { return _todayOpeningCount; }

private:
    void CheckAndResetDaily();                   // 跨日重置计数器
};

//--------------------------------------------------------------------
// 构造
//--------------------------------------------------------------------
CTimingTracker::CTimingTracker() {
    _config = NULL;
    _lastOpeningTime = 0;
    _todayOpeningCount = 0;
    _todayDate = 0;
}

//--------------------------------------------------------------------
// 初始化
//--------------------------------------------------------------------
bool CTimingTracker::Init(CBaseConfig *config) {
    if (config == NULL) return false;
    _config = config;

    _logger.Enable(true);
    _logger.SetModuleName("时间跟踪");
    _logger.SetLogLevel(_config.LogLevel);

    _logger.LogInfo("时间跟踪器初始化成功");
    return true;
}

//--------------------------------------------------------------------
// 记录开仓
//--------------------------------------------------------------------
void CTimingTracker::RecordOpening(datetime time) {
    CheckAndResetDaily();
    _lastOpeningTime = time;
    _todayOpeningCount++;
    _logger.LogDebug(StringFormat("记录开仓：今日第%d次，时间=%s",
                                 _todayOpeningCount, TimeToString(time)));
}

//--------------------------------------------------------------------
// 判断是否应启用保底机制
//--------------------------------------------------------------------
bool CTimingTracker::ShouldEnableMinimalEntry() {
    if (!_config.EnableMinimalEntry) return false;

    CheckAndResetDaily();

    int hoursSince = GetHoursSinceLastOpening();
    MqlDateTime now;
    TimeToStruct(TimeCurrent(), now);

    // 条件1：距上次开仓≥配置的最小小时数
    if (hoursSince >= _config.MinimalEntryMinHours) {
        _logger.LogInfo(StringFormat("启用保底机制：距上次开仓%d小时 >= 门槛%d小时",
                                    hoursSince, _config.MinimalEntryMinHours));
        return true;
    }

    // 条件2：今日尚未开仓 且 已过开盘指定时间
    if (_todayOpeningCount == 0 && now.hour >= _config.MinimalEntryAfterHour) {
        _logger.LogInfo(StringFormat("启用保底机制：今日尚未开仓且已过%d点（当前%d点）",
                                    _config.MinimalEntryAfterHour, now.hour));
        return true;
    }

    return false;
}

//--------------------------------------------------------------------
// 计算距上次开仓的小时数
//--------------------------------------------------------------------
int CTimingTracker::GetHoursSinceLastOpening() {
    if (_lastOpeningTime == 0) return 999;  // 未开过仓，返回极大值
    return (int)((TimeCurrent() - _lastOpeningTime) / 3600);
}

//--------------------------------------------------------------------
// 跨日重置计数器
//--------------------------------------------------------------------
void CTimingTracker::CheckAndResetDaily() {
    MqlDateTime now;
    TimeToStruct(TimeCurrent(), now);
    datetime today = TimeCurrent() - now.hour * 3600 - now.min * 60 - now.sec;

    if (today != _todayDate) {
        _todayDate = today;
        int oldCount = _todayOpeningCount;
        _todayOpeningCount = 0;
        _logger.LogInfo(StringFormat("跨日重置：日期=%s，昨日开仓%d次，今日计数归零",
                                    TimeToString(today, TIME_DATE), oldCount));
    }
}

#endif
