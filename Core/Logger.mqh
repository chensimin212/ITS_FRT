#property strict
#ifndef CONTROLLED_MARTINGALE_CORE_LOGGER_MQH
#define CONTROLLED_MARTINGALE_CORE_LOGGER_MQH

#include <Object.mqh>
#include "./Enums.mqh"

//----------------------------------------------------------------
// CLogger 类 - 日志系统
//----------------------------------------------------------------
class CLogger : public CObject {
private:
    string _name;           // 模块名，用于标识日志来源
    bool _enabled;          // 全局开关，false 时所有日志不输出
    E_LOG_LEVEL _threshold; // 日志等级阈值，低于阈值的日志不输出

    //---------------------- 私有方法 ----------------------
    void PrintLog(E_LOG_LEVEL level, string message); // 输出日志到终端

public:
    //--------------------------------------------------------------------
    // 构造日志器并默认关闭输出、使用 INFO 阈值。
    //--------------------------------------------------------------------
    CLogger(void) {
        _enabled = false;
        _threshold = LOG_INFO;
    }
    //--------------------------------------------------------------------
    // 析构日志器；不持有外部输出资源。
    //--------------------------------------------------------------------
    ~CLogger(void) {
    }
    void Enable(bool en = true);           // 开启/关闭日志
    void SetModuleName(string moduleName); // 设置模块名
    void SetLogLevel(E_LOG_LEVEL level);   // 设置日志等级阈值

    void LogDebug(string message); // 调试信息
    void LogInfo(string message);  // 普通信息
    void LogWarn(string message);  // 警告信息
    void LogError(string message); // 错误信息
    void LogFatal(string message); // 致命错误信息

    bool LogDebug4Boolean(string message, bool result = false); // 调试提示，返回布尔值
    bool LogInfo4Boolean(string message, bool result = false);  // 信息提示，返回布尔值
    bool LogWarn4Boolean(string message, bool result = false);  // 警告提示，返回布尔值
    bool LogError4Boolean(string message, bool result = false); // 错误提示，返回布尔值
    bool LogFatal4Boolean(string message, bool result = false); // 致命提示，返回布尔值

    int LogDebug4Int(string message, int result = 0); // 调试提示，返回整数值
    int LogInfo4Int(string message, int result = 0);  // 信息提示，返回整数值
    int LogWarn4Int(string message, int result = 0);  // 警告提示，返回整数值
    int LogError4Int(string message, int result = 0); // 错误提示，返回整数值
    int LogFatal4Int(string message, int result = 0); // 致命提示，返回整数值

    double LogDebug4Double(string message, double result = 0.0); // 调试提示，返回双精度值
    double LogInfo4Double(string message, double result = 0.0);  // 信息提示，返回双精度值
    double LogWarn4Double(string message, double result = 0.0);  // 警告提示，返回双精度值
    double LogError4Double(string message, double result = 0.0); // 错误提示，返回双精度值
    double LogFatal4Double(string message, double result = 0.0); // 致命提示，返回双精度值

    void AlertError(string message);                               // 弹窗错误提示
    bool AlertError4Boolean(string message, bool result = false);  // 弹窗错误提示，返回布尔值
    int AlertError4Int(string message, int result = 0);            // 弹窗错误提示，返回整数值
    double AlertError4Double(string message, double result = 0.0); // 弹窗错误提示，返回双精度值
};

//--------------------------------------------------------------------
// 开启/关闭日志
//--------------------------------------------------------------------
void CLogger::Enable(bool en) {
    // en: 是否开启
    _enabled = en;
}

//--------------------------------------------------------------------
// 设置模块名
//--------------------------------------------------------------------
void CLogger::SetModuleName(string moduleName) {
    // moduleName: 模块名称
    _name = moduleName;
}

//--------------------------------------------------------------------
// 设置日志等级阈值
//--------------------------------------------------------------------
void CLogger::SetLogLevel(E_LOG_LEVEL level) {
    // level: 日志等级
    _threshold = level;
}

//--------------------------------------------------------------------
// 调试信息
//--------------------------------------------------------------------
void CLogger::LogDebug(string message) {
    // message: 提示字符串
    PrintLog(LOG_DEBUG, message);
}

//--------------------------------------------------------------------
// 普通信息
//--------------------------------------------------------------------
void CLogger::LogInfo(string message) {
    // message: 提示字符串
    PrintLog(LOG_INFO, message);
}

//--------------------------------------------------------------------
// 警告信息
//--------------------------------------------------------------------
void CLogger::LogWarn(string message) {
    // message: 提示字符串
    PrintLog(LOG_WARN, message);
}

//--------------------------------------------------------------------
// 错误信息
//--------------------------------------------------------------------
void CLogger::LogError(string message) {
    // message: 提示字符串
    PrintLog(LOG_ERROR, message);
}

//--------------------------------------------------------------------
// 致命错误信息
//--------------------------------------------------------------------
void CLogger::LogFatal(string message) {
    // message: 提示字符串
    PrintLog(LOG_FATAL, message);
}

//--------------------------------------------------------------------
// 调试提示
//--------------------------------------------------------------------
bool CLogger::LogDebug4Boolean(string message, bool result) {
    LogDebug(message);
    return result;
}

//--------------------------------------------------------------------
// 信息提示
//--------------------------------------------------------------------
bool CLogger::LogInfo4Boolean(string message, bool result) {
    LogInfo(message);
    return result;
}

//--------------------------------------------------------------------
// 警告提示
//--------------------------------------------------------------------
bool CLogger::LogWarn4Boolean(string message, bool result) {
    LogWarn(message);
    return result;
}

//--------------------------------------------------------------------
// 错误提示
//--------------------------------------------------------------------
bool CLogger::LogError4Boolean(string message, bool result) {
    LogError(message);
    return result;
}

//--------------------------------------------------------------------
// 致命提示
//--------------------------------------------------------------------
bool CLogger::LogFatal4Boolean(string message, bool result) {
    LogFatal(message);
    return result;
}

//--------------------------------------------------------------------
// 调试提示
//--------------------------------------------------------------------
int CLogger::LogDebug4Int(string message, int result) {
    LogDebug(message);
    return result;
}

//--------------------------------------------------------------------
// 信息提示
//--------------------------------------------------------------------
int CLogger::LogInfo4Int(string message, int result) {
    LogInfo(message);
    return result;
}

//--------------------------------------------------------------------
// 警告提示
//--------------------------------------------------------------------
int CLogger::LogWarn4Int(string message, int result) {
    LogWarn(message);
    return result;
}

//--------------------------------------------------------------------
// 错误提示
//--------------------------------------------------------------------
int CLogger::LogError4Int(string message, int result) {
    LogError(message);
    return result;
}

//--------------------------------------------------------------------
// 致命提示
//--------------------------------------------------------------------
int CLogger::LogFatal4Int(string message, int result) {
    LogFatal(message);
    return result;
}

//--------------------------------------------------------------------
// 调试提示
//--------------------------------------------------------------------
double CLogger::LogDebug4Double(string message, double result) {
    LogDebug(message);
    return result;
}

//--------------------------------------------------------------------
// 信息提示
//--------------------------------------------------------------------
double CLogger::LogInfo4Double(string message, double result) {
    LogInfo(message);
    return result;
}

//--------------------------------------------------------------------
// 警告提示
//--------------------------------------------------------------------
double CLogger::LogWarn4Double(string message, double result) {
    LogWarn(message);
    return result;
}

//--------------------------------------------------------------------
// 错误提示
//--------------------------------------------------------------------
double CLogger::LogError4Double(string message, double result) {
    LogError(message);
    return result;
}

//--------------------------------------------------------------------
// 致命提示
//--------------------------------------------------------------------
double CLogger::LogFatal4Double(string message, double result) {
    LogFatal(message);
    return result;
}

//--------------------------------------------------------------------
// 弹窗错误提示
//--------------------------------------------------------------------
void CLogger::AlertError(string message) {
    Alert("【ERROR】", _name, " => ", message);
}

//--------------------------------------------------------------------
// 弹窗错误提示
//--------------------------------------------------------------------
bool CLogger::AlertError4Boolean(string message, bool result) {
    Alert("【ERROR】", _name, " => ", message);
    return result;
}

//--------------------------------------------------------------------
// 弹窗错误提示
//--------------------------------------------------------------------
int CLogger::AlertError4Int(string message, int result) {
    Alert("【ERROR】", _name, " => ", message);
    return result;
}

//--------------------------------------------------------------------
// 弹窗错误提示
//--------------------------------------------------------------------
double CLogger::AlertError4Double(string message, double result) {
    Alert("【ERROR】", _name, " => ", message);
    return result;
}

//*********************************私有方法***********************

//--------------------------------------------------------------------
// 内部实现
//--------------------------------------------------------------------
void CLogger::PrintLog(E_LOG_LEVEL level, string message) {
    if (!_enabled) return;                                // 日志关闭直接返回
    if (level != LOG_FATAL && level < _threshold) return; // FATAL日志总是输出，其余低于阈值则跳过

    string prefix;
    switch (level) {
    case LOG_DEBUG: prefix = "DEBUG"; break;
    case LOG_INFO: prefix = "INFO"; break;
    case LOG_WARN: prefix = "WARN"; break;
    case LOG_ERROR: prefix = "ERROR"; break;
    case LOG_FATAL: prefix = "FATAL"; break;
    }

    PrintFormat("【%s】%s => %s", prefix, _name, message);
}

#endif
