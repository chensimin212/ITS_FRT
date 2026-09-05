#ifndef ITS_FRT_CONFIG_PROCONFIG_MQH
#define ITS_FRT_CONFIG_PROCONFIG_MQH
//+------------------------------------------------------------------+
//|                                                  ITS_FRT_V1.0    |
//|                                         Copyright 2026, RockChen |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property strict

#include <Object.mqh>
#include "./BaseConfig.mqh"
#include "../Core/Consts.mqh"

//--------------------------------------------------------------------
// CProConfig - EA 配置类（生产环境）
//--------------------------------------------------------------------
class CProConfig : public CBaseConfig {
public:
    CProConfig();  // 构造生产配置对象
    ~CProConfig(); // 析构生产配置对象

protected:
    bool InitEnvironment() override; // 初始化环境
    bool LoadFunction() override;    // 加载功能配置
};

//--------------------------------------------------------------------
// 构造函数
//--------------------------------------------------------------------
CProConfig::CProConfig() {
}

//--------------------------------------------------------------------
// 析构函数
//--------------------------------------------------------------------
CProConfig::~CProConfig() {
}

//--------------------------------------------------------------------
// 初始化环境
//--------------------------------------------------------------------
bool CProConfig::InitEnvironment() override {
    if (LogLevel < PRO_MIN_LOG_LEVEL) {
        LogLevel = LOG_INFO;
    }

    _logger.Enable(true);
    _logger.SetModuleName("生产配置");
    _logger.SetLogLevel(LogLevel);
    return true;
}

//--------------------------------------------------------------------
// 加载功能配置
//--------------------------------------------------------------------
bool CProConfig::LoadFunction() override {
    return false; // 生产环境不加载功能配置
}

#endif
