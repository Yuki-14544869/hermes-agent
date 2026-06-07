# 测试设计说明书 (Test Design)

## [v0.16.0-elysia.0.1.0] - 2026-06-07

### 1. 记忆与技能路由测试
**用例名称**：`test_semantic_routing_schemas`
- **前置条件**：读取当前 Agent 的 Tool 注册表。
- **操作步骤**：提取 `memory_tool` 与 `skill_manage` 的 JSON Schema 定义。
- **预期结果**：
  - `memory_tool` 的 description 中包含 `DO NOT save procedural workflows` 字符串。
  - `skill_manage` 的 description 中包含 `ROUTING RULE` 相关的严格约束。
