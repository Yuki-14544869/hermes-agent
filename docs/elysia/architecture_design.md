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

## [v0.16.0-elysia.0.3.0] - 2026-06-07

### 3. 网关保活与重启探测 (Gateway Resilience)
- **优雅退让 (Grace Period)**：为 Slack Socket Watchdog 引入 60s 定时器 `asyncio.sleep(GRACE_PERIOD_SECONDS)`，如果在宽限期内底层自动重连成功，则 Watchdog 中止强杀干预，避免与 SDK 发生竞态。
- **冷启动拦截**：在 `gateway/run.py` 补充捕获 OS 的 SIGTERM 逻辑，拉起 Socket 后向前端广播 ♻️ Gateway online 通知。

## [v0.16.0-elysia.0.3.1] - 2026-06-07

### 4. 中间件时序防护 (Middleware Shield)
- **防呆处理**：通过安全访问层 (`getattr`) 为中间件链式拦截提供降级空字典处理，实现系统底层实例初始化时序错乱时的兜底保护。
