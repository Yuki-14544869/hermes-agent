# 架构设计说明书 (Architecture Design)

## 1. 核心设计原则
遵循 Hermes Agent 的核心扩展与分离原则：
- **无状态化**：Prompt 增强与路由引导不能侵入业务逻辑执行体，仅在 Schema 定义与调度层生效。
- **降级容灾**：所有网络依赖与外部 API（大模型、搜索引擎）均需实现幂等的异常捕获与后备资源拉起策略。
- **高内聚低耦合**：将部署脚本、运维逻辑等独立隔离在 `scripts/elysia` 中，禁止对核心引擎目录造成污染。

## 2. 模块架构设计

### 2.1 语义路由网关 (Semantic Router)
- **拦截层 (Interceptor Layer)**：通过自然语言结构强化 `skills_tool.py`、`memory_tool.py` 和 `skill_manager_tool.py` 中的 Description 与 Prompt 边界。
- **强制约束设计**：
  - 对 Memory Tool 添加硬性警告：`[CRITICAL] DO NOT save procedural workflows...`。
  - 对 Skill Manage 添加路由引导：`[ROUTING RULE] When the user says 'remember this'...` 强制转移控制流至技能层。

### 2.2 搜索可用性架构 (Search Fallback Topology)
- 采用链式调用架构。当调用 `SearXNG` API 超时或抛出 HTTP 5xx 错误时，`web_tools.py` 的异常捕获器将触发自动重定向。
- **Fallback 链路**：
  1. Primary: Self-hosted SearXNG
  2. Secondary: Brave Search API
  3. Tertiary: DuckDuckGo (HTML Parsing Backup)

### 2.3 状态驱动通信体系 (State-driven Notification)
- **LLM Fallback 触发器**：修改 `chat_completion_helpers.py`。当检测到上游大模型提供商（如 Anthropic/OpenAI）限流、超时或无响应而切换至备用模型时，立刻通过 `_emit_status()` 触发即时 UI 状态通知。
- **重启信号拦截 (SIGTERM Trap)**：在 `gateway/run.py` 补充捕获 OS 信号逻辑。记录重启标志位，并在 Gateway 重启流程执行完成拉起 Socket 后，检测标志位并推送上下线通知，实现冷热启动状态可观测。

### 2.4 网关高可用机制 (Slack Watchdog Grace Period)
- **问题分析**：Slack SDK 的 `auto_reconnect` 与外部监控协程构成双向竞争。
- **优雅退让设计**：
  - Watchdog 捕获到链路断开后，不立刻执行重连动作。
  - 启动定时器：`asyncio.sleep(GRACE_PERIOD_SECONDS)` (默认 60s)。
  - 若在宽限期内监测到连接状态恢复为 True，则中止重连操作（Stand Down）；反之再执行强制 Socket 层重拉。
