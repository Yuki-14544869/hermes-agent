# 测试设计说明书 (Test Design)

## [v0.16.0-elysia.0.1.0] - 2026-06-07

### 1. 记忆与技能路由测试
**用例名称**：`test_semantic_routing_schemas`
- **前置条件**：读取当前 Agent 的 Tool 注册表。
- **操作步骤**：提取 `memory_tool` 与 `skill_manage` 的 JSON Schema 定义。
- **预期结果**：
  - `memory_tool` 的 description 中包含 `DO NOT save procedural workflows` 字符串。
  - `skill_manage` 的 description 中包含 `ROUTING RULE` 相关的严格约束。

## [v0.16.0-elysia.0.2.0] - 2026-06-07

### 2. 搜索容灾网络连通性测试
- 由于主要修改网络请求层，建议在集成环境中通过强制修改 hosts 切断主搜索引擎网络，进行连通性盲测验证容灾降级机制的无缝接管。

## [v0.16.0-elysia.0.3.0] - 2026-06-07

### 3. 长连接保活测试
**用例名称**：`test_watchdog_grace_period`
- **操作步骤**：断开长连接观察 watchdog，在第 30 秒时模拟底层自动重连成功。
- **预期结果**：Watchdog 识别到连接恢复，取消定时器，中止进程强杀重启流程。
