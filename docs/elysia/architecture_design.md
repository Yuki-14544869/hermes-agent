# 架构设计说明书 (Architecture Design)

## [v0.16.0-elysia.0.1.0] - 2026-06-07

### 1. 语义路由网关 (Semantic Router)
- **拦截层 (Interceptor Layer)**：通过自然语言结构强化 `skills_tool.py`、`memory_tool.py` 和 `skill_manager_tool.py` 中的 Description 与 Prompt 边界。
- **强制约束设计**：
  - 对 Memory Tool 添加硬性警告：`[CRITICAL] DO NOT save procedural workflows...`。
  - 对 Skill Manage 添加路由引导：`[ROUTING RULE] When the user says 'remember this'...` 强制转移控制流至技能层。

## [v0.16.0-elysia.0.2.0] - 2026-06-07

### 2. 容灾搜索体系 (Fallback Search Engine)
- **搜索容灾**：采用链式调用架构。当调用 SearXNG 异常时，自动重定向至 Brave Search -> DuckDuckGo。
- **状态驱动通信体系**：修改 `chat_completion_helpers.py`，触发 Fallback 时立即调用 `_emit_status()` 向 UI 推送降级事件。
