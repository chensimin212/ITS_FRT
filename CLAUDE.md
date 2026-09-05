# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

MQL5 项目（MetaTrader 5 EA）：单品种单图表日内交易系统 **ITS_FRT_V1.0**（Intraday Trading System - Fixed Risk），当前是只有 熔断 → 定时清仓 → 尾随止损 三条防守链路的**最小防御框架**。

> **改动范围**：只改本目录（`ITS_FRT_V1.0/`）下的文件，不碰目录之外（含平台 `MQL5/Include` 标准库）。注释、模块名、日志一律中文。

## 工作原则

先检查问题有没有错误前提、逻辑跳跃和信息缺失；不要迎合我，要独立判断；区分事实、推测和主观观点；涉及数字、人物和结论时尽量核实来源；不同意就直接指出，并给出依据、风险和替代解释；还要主动提醒我忽略的变量、成本和偏差。

## 事实来源

**当前代码与真实调用路径是唯一权威。** `docs/` 下的报告只作设计意图与背景参考，可能滞后于实现。文档与实现冲突时**先指出冲突**再动手，不要改代码去对齐文档；也不要凭命名或注释推断行为。

已知的运行期阻塞与遗留问题清单在 `docs/项目完成报告-20260904-final.md`（每条带 file:line，运行期结论均为静态审查、无测试器实跑证据）——下「能不能跑」的结论前先按该清单核对代码现状，不要照抄清单本身。

## 探索代码

先用 codegraph：`codegraph_explore`（一次返回相关符号源码，等价于 Read）、`codegraph_callers` / `codegraph_callees` / `codegraph_impact`（查引用与改动影响面）；索引为空时回退 `Read` / `Grep`。不要无故整读 `.mqh`。

## 强制工作流：两个 skill 不可省

- **动 `.mq5` / `.mqh` 之前**（审查、写新代码、改代码、修缺陷、提方案）：显式调用 `mql5-reviewing-code`，读完它要求的全部引用，按它的交易安全 / 平台语义 / 架构 / 命名 / 控制流 / 返回值 / 调用深度检查执行，**不得用非正式的手工 review 代替**。
- **改完之后**：显式调用 `mq5-compile` 编译，并再次用 `mql5-reviewing-code` 复核改动与受影响调用路径。
- **每一轮改动都要重新走这两个 skill**，不得用上一轮的审查或编译结论顶替；`mq5-compile` 不得换成临时手敲的编译命令。
- 动手前先定位职责所属层，读实现、调用方、依赖、状态生命周期、失败路径与配置链；改完自查有无误入的文件、架构违规、命名问题、配置链缺环与生成物。
- **未拿到 `0 errors, 0 warnings` 不得声称完成**，警告一律视为缺陷。纯文档改动免编译。
- 策略测试器在当前环境跑不了时**明说**，不得用「编译通过」冒充行为回归。

## 分层与依赖

目录即层，依赖**始终单向**；`ITS_FRT_V1.0.mq5` 是组成根，持有全部 `_g` 前缀全局单例与生命周期回调，业务规则不写在这里。

```text
ITS_FRT_V1.0.mq5 → Manager → Signal / Module → Api → State / Model → Config → Core
```

高层可按既有设计依赖低层（Manager 直接 include `Core/Logger.mqh`、`Config/BaseConfig.mqh` 是允许的）；**低层不得依赖高层**，不得循环 include，不得服务定位器式的隐藏全局依赖。各层的配置与状态**一律由 `CContext` 注入**，不自行 new 或读全局单例。

新代码放进最窄的匹配层：

| 层 | 职责 | 禁止 |
|---|---|---|
| `Core/` | 常量、枚举、日志等基础设施原语 | 策略判定、持有市场状态、下单 |
| `Config/` | input 声明、字段、加载、校验 | 每轮行情读取、交易动作 |
| `Model/` | 被动数据结构与快照 | 平台读取、编排、下单 |
| `State/` | 账户 / 品种 / 仓位 / 市场 / 交易状态的刷新与发布 | 决定是否开仓、提交订单 |
| `Api/` | **唯一**提交 / 修改 / 平仓层；归属过滤、归一化、retcode 诊断 | 判断信号是否成立 |
| `Module/` | 可复用的风控、止损、手数计算；失败显式上抛 | 编排 tick 生命周期、吞掉失败 |
| `Manager/` | 编排：门控 → 调模块 → 经 `CTradeApi` 提交 → 刷新状态 | 重复实现指标、归一化、底层交易请求 |

- 跨层接口只暴露消费方**必需的最小数据与操作**，不把平台实现细节向上泄漏。
- 一个类一个明确的所有者、一个主职责；开始协调无关层或复制别层策略时就该拆。
- 把职责搬到另一层时，**同一次改动内**更新全部调用方、依赖、初始化顺序、校验与文档。

## 生命周期与执行顺序

**`OnInit` 依赖序**（构造顺序即依赖顺序，任一失败返回 `INIT_FAILED`）：配置 → 日志 → `CContext` → `CTradeApi` → `CRiskController` → TradingManager → ClosingManager → OpeningManager → TrailingManager。

**`OnTick` 顺序**（除经批准的设计变更外不得调整）：

1. 门控：新 bar 或新价格
2. `_gContext.Refresh()`——按 账户 → 品种 → 仓位 → 市场 顺序刷新，任一步失败即暂停开仓并跳过该轮；刷新或取数失败**绝不允许**复用旧值做新的交易决策
3. `TradingManager`：熔断判定 + 终止态清仓
4. `ClosingManager`：定时清仓的暂停窗口 / 清仓窗口（终止态直接让行给 TradingManager）
5. `TrailingManager`：保护既有仓位
6. `OpeningManager`：空壳，直接 return

开仓 / 平仓 / 改单成功后必须立即触发「仓位变化后刷新」（`CContext::RefreshAfterPositionChange()`），保证同一轮后续管理器读到最新敞口。

通用不变量：生命周期回调保持薄（门控 → 刷新所需状态 → 委派编排层）；状态只在完整刷新成功后发布，不暴露半更新的快照；指标句柄一类资源由明确的所有者持有，并按既定路径释放。

## 配置闭环

`Core/Consts.mqh` 的 `USE_PRO_CONFIG` 决定条件编译：默认注释掉 → `CTestConfig`（从 MT5 输入面板加载）；定义该宏 → `CProConfig`，但其 `LoadFunction()` 直接 `return false`（`ProConfig.mqh:56-58`）且 `ProInputs.mqh` 无人 include → Pro 模式必然初始化失败。`ProConfig` / `ProInputs` 是**生产分支保留件，不是死代码，不要删**；下任何「参数怎么加载」的结论前先确认编译的是哪个分支。

现有 input 共 18 个：`Config/SysInputs.mqh` 4 个（`InpTickPoints` 已无消费方）+ `Config/FuncInputs.mqh` 14 个（风控 7 / 订单执行 1 / 定时清仓 2 / 尾随止损 4）。`Symbol = _Symbol`（`BaseConfig.mqh:192`）与 `TradeTimeframe = PERIOD_M5`（`TestConfig.mqh:59`）是代码内固定项。

增删配置参数必须走完整闭环，缺一环就会「参数不生效」或「非法值被放行」——当前 P0 阻塞正是反向漏环（删了加载与消费，留下字段与校验）：

```text
SysInputs / FuncInputs 加 input 声明
  → BaseConfig.mqh 加 public 字段
  → TestConfig.mqh 加载
  → CBaseConfig::CheckInputs() 加范围校验
  → 实际消费方
```

声明、字段、加载、校验四处的分组与顺序保持一致；单值范围与跨字段约束都要在依赖对象初始化前校验通过——**漏校验等于放行非法参数**；布尔开关必须**完全绕过**对应功能；`0 = 不限制` 一类哨兵值与量纲在声明、校验、消费三处口径一致。

## 交易与 MQL5 安全

细则见 `mql5-reviewing-code`，以下是底线：

- 买用 Ask、卖用 Bid，凡平台语义要求处不得混用。
- 订单 / 仓位 / 成交的每次遍历都按 **Symbol + Magic + ticket** 过滤归属（`PositionState.mqh:96-97`）。
- 价格按 TickSize / Digits 归一化，手数按 min / max / step / limit 归一化；提交前检查 StopsLevel、FreezeLevel、点差、保证金与配置风险上限。
- **交易函数返回成功不等于成交**：必须查 retcode，并保留请求上下文与平台错误码用于诊断。
- 指标句柄查 `INVALID_HANDLE`，取数校验实际条数再索引；shift `0` 是未收的当前 K，shift `1` 是最新已收 K，只按已收 K 决策。
- 盈亏 / 保证金试算失败一律**保守拒绝开仓**并记 ERROR，不得当 0 继续。
- 保护价只允许**收紧**；绝不放宽止损、混用方向语义、无界重试，或在同一轮产生重复交易副作用。

## 核心设计原则（不可违反）

1. **固定风险模式**：风险与保证金预算、手数计算基于配置固定值 `FixedRiskEquity`，不随账户净值浮动（`RiskController.mqh:82-84`）；只有回撤 / 熔断判定用实际净值。
2. **状态机单调递增**：`E_TRADING_STATE` NORMAL → PAUSED → LIQUIDATING → TERMINATED 只升不降。
3. **篮子锁盈优先**：方向整体锁定净收益为正时统一推进所有同向腿，未触发再回退逐笔锁盈。
4. **管理器执行顺序固定**：熔断 → 定时清仓 → 尾随 → 开仓。

下列属**设计取舍、非缺陷**，勿当 bug「修复」：熔断终止后需人工重启 EA；启动期指标未预热时跳过该轮、就绪后自愈；交易状态机不可降级。

## 工程约定

- **文件编码**：`.mq5` / `.mqh` 一律 **UTF-8 带 BOM**（`.md` 无 BOM）。**不要用 PowerShell `Set-Content` / `Out-File` 改源文件**——会静默剥离 BOM 并弄乱中文注释，而编译照样通过；用 Write / Edit 工具。
- **代码风格**：4 空格缩进。本项目**无 `.clang-format`**，大括号位置（同行 / 换行）与行尾（CRLF / LF）在文件间不一致，改动时**保持所在文件原样**，不要顺手重排格式或 include 顺序。
- **头文件保护宏**：新旧两套前缀混用——旧 `CONTROLLED_MARTINGALE_<DIR>_<NAME>_MQH`，新 `ITS_FRT_<DIR>_<NAME>_MQH`。**沿用所在文件现状，不要统一**；超长宏名会触发 MetaEditor `error 126`，按既有做法缩写目录 / 文件段。
- **include**：项目内一律相对路径 `"../..."`；`<...>` 只用于平台标准库。
- **文件名 ↔ 主类名**：去掉 `C` 前缀即文件名（`CTradeApi` → `TradeApi.mqh`）。
- **命名**：类 `C` + PascalCase；接口 `I` + PascalCase；结构体 `S` + PascalCase；枚举类型 `E_` + UPPER_SNAKE_CASE，枚举值域前缀 + UPPER_SNAKE_CASE；input `Inp` + PascalCase；全局对象 `_g` + PascalCase；公开成员 PascalCase（布尔查询以 `Is` / `Has` / `Can` / `Should` 开头）；局部与参数 lowerCamelCase；私有 / 保护成员 `_lowerCamelCase`；常量与宏 UPPER_SNAKE_CASE。
- **日志每实例独立**：各类持有自己的 `_logger`，在自身 `Init()` 里设好开关 / 模块名 / 级别再用；漏设模块名会让日志无法定位来源。
- **非平凡方法实现写在类声明之外**，前面加简洁的中文职责注释块；**嵌套方法调用深度控制在 2 层内**。
- 每个可能失败的平台 / API 返回值都要先判再用；改相邻代码时顺手就地修正笔误。
- 看似缺陷的行为**先确认是不是既有设计取舍**（本项目有多处为交易安全而故意保守的行为），确认前不要当 bug「修复」，也不要为对齐文档去改代码。

## 构建与测试

- **编译目标**：`ITS_FRT_V1.0.mq5`——`.mqproj` 中唯一 `"compile": true` 的条目，其余 `.mqh` 仅头文件。
- **编译方式**（优先级从高到低）：① `mq5-compile` skill（脚本 `~/.claude/skills/mq5-compile/scripts/compile.ps1`，**无参数，必须在项目根目录执行**）② 手工 `& 'C:\Program Files\MetaTrader 5\metaeditor64.exe' /compile:ITS_FRT_V1.0.mq5 /log:compile.log` ③ MetaEditor 里打开 `.mqproj` 按 **F7**。
- **判定标准**：MetaEditor 是 GUI 进程，**退出码不可信**；只认日志末行 `Result: N errors, M warnings`。
- **`0 errors, 0 warnings` 不等于可运行**：配置校验失败发生在运行期 `OnInit()`，未被 include 的文件也不进编译单元，两类问题编译器都看不到，别用编译结果推断可部署性。
- **无自动化测试框架**：涉及交易行为、状态时序、风控、下单、止损或配置语义的改动须在策略测试器手工回归，按改动面覆盖初始化失败、数据未就绪、门控、下单被接受 / 被拒、保证金与风险上限、定时清仓、尾随、熔断、刷新失败与自恢复；记录品种、周期、日期范围、模型、关键参数与结果。报告时明确区分「已验证」与「未验证」。
- **产物**：`.ex5` 与编译日志本地保留、不得提交。

## Git 与生成物

- 当前目录**不是 git 仓库**；若后续初始化，以下规则即生效。
- **禁止自动执行 git 状态变更**：`git add` / `commit` / `push` / 建分支 / 开 PR 必须先取得我的明确同意；可以准备内容与备注建议，但不可直接执行。
- 只暂存属于本次改动的文件，保留工作区里无关的脏文件与我的改动。
- 备注写清「改了什么 + 为什么」：标题 `<type>: <中文简述>` 一行写完，需要展开时正文用 `-` 列要点；禁止 `update` / `修改` / `fix bug` 这类无信息量备注；一次提交只做一件事。改参数、阈值、量纲时写明「旧值 → 新值」及依据。
- PR 需说明行为变化、受影响的输入 / 模块、架构与风险影响、验证证据。
- **禁止提交**：凭证、账户标识、终端日志、生成的 `.ex5`、临时编译产物。

<!-- rtk-instructions v2 -->
## RTK

命令一律加 `rtk` 前缀（含 `&&` 链里的每一段）：有专用过滤器就用，没有就原样透传，因此始终安全。完整命令表见全局 `~/.claude/RTK.md`（每次会话自动加载），此处不重复；需要在本文件内还原完整清单可跑 `rtk init`。
<!-- /rtk-instructions -->
