# 测试设计说明书 (Test Design)

## 1. 测试策略
采用分层测试策略：
- **静态分析与代码格式检查**：使用 Ruff 进行严格风格校验，确保代码满足 Google Coding Style 规范。
- **单元测试 (Unit Test)**：补全边缘条件覆盖，特别是 Gateway 层的异步并发竞争测试。
- **功能集成测试 (Integration Test)**：通过现有测试套件验证整体链路逻辑不受影响。

## 2. 关键测试用例 (Test Cases)

### 2.1 Slack Watchdog 优雅退让测试
**用例名称**：`test_watchdog_grace_period`
- **前置条件**：模拟启动 Slack Gateway，并主动断开底层长连接。
- **操作步骤**：
  1. 触发连接断开事件，观察 watchdog 状态是否进入 60 秒倒计时。
  2. 在第 30 秒时，模拟底层 SDK 的 `auto_reconnect` 成功重建连接。
- **预期结果**：Watchdog 识别到连接恢复，取消定时器，中止强杀重启流程。
- **状态验证**：验证该代码位于 `tests/gateway/test_slack.py` 中且执行通过。

### 2.2 记忆与技能路由测试
**用例名称**：`test_semantic_routing_schemas`
- **前置条件**：读取当前 Agent 的 Tool 注册表。
- **操作步骤**：提取 `memory_tool` 与 `skill_manage` 的 JSON Schema 定义。
- **预期结果**：
  - `memory_tool` 的 description 中包含 `DO NOT save procedural workflows` 字符串。
  - `skill_manage` 的 description 中包含 `ROUTING RULE` 相关的严格约束。

### 2.3 中间件防崩溃测试
**用例名称**：`test_middleware_uninitialized_access`
- **前置条件**：构造未调用初始化的 `PluginManager` 实例。
- **操作步骤**：通过外界调用尝试读取/执行其 hook 函数。
- **预期结果**：`getattr` 生效，回落至空字典机制，系统不会抛出 `AttributeError` 异常，应用不崩溃。

---

# 变更日志 (Changelog)

## [vElysia-Rebuild] - 2026-06-07

### Added (新增功能)
- **Router**: 强化记忆与技能的路由约束，彻底解决过程性知识污染持久化状态的问题。
- **Search**: 增加 SearXNG -> Brave Search -> DuckDuckGo 的容灾降级功能。
- **UX**: 当请求触发 LLM 引擎降级调用时，立刻在 UI 层下发状态转移通知。
- **Gateway**: 为 Slack 连接保活机制引入 60 秒的优雅退让宽限期，防止与内部自动重连模块陷入竞争导致抖动。
- **Gateway**: SIGTERM 重启触发的冷拉起现在会自动向终端广播 `♻️ Gateway online` 信息。
- **DevOps**: 引入 `elysia/safe_update.sh` 与 `safe_push.sh` 脚本，保障生产环境安全迭代。

### Fixed (修复缺陷)
- **Middleware**: 修复 `PluginManager._middleware` 在初始化时序错乱时的属性访问奔溃问题。
- **Repo Health**: 移除了违规提交的内置 Memory 插件与本地垃圾缓存，将历史 9 个杂乱提交清理、拆解为符合开源社区规范的整洁 Commit。
