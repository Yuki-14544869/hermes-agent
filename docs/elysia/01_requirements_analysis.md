# 需求分析说明书 (Requirements Analysis)

## 1. 背景概述
在 `elysias-pink-realm` 分支的迭代过程中，系统引入了多项增强功能，包括路由层面的记忆约束、容灾搜索、基础设施即代码（IaC）部署脚本以及网关层的稳定性修复。由于历史补丁由不同模型生成，存在结构混乱、包含冗余及违规文件等问题，故需进行系统化拆解与规范化。

## 2. 功能需求详情

### 2.1 强路由约束与过程性知识拦截 (Memory/Skill Routing)
- **问题描述**：Agent 存在将“多步操作流程”、“格式规范”等过程性知识错误写入持久化事实记忆（Memory）的问题，导致上下文污染。
- **功能需求**：
  - 修改 `memory_tool`、`skill_manager_tool` 和 `skills_tool` 的系统提示语（Prompt/Schema）。
  - 强制性区分“声明式事实（如用户操作系统、偏好）”与“过程性知识（如代码规范、多步工作流）”。
  - 明确指令：过程性知识必须存入 Skill，事实性知识存入 Memory。

### 2.2 容灾搜索与状态下发 (Resilient Search & Fallback UI)
- **问题描述**：主搜索引擎（SearXNG）偶发不可用，导致涉及搜索的复杂任务直接中断；大模型发生 Fallback 时，UI 端缺乏即时反馈。
- **功能需求**：
  - 在 `web_tools.py` 中构建多级搜索 fallback 策略：SearXNG -> Brave Search -> DuckDuckGo。
  - 当 LLM 触发降级（Fallback）策略时，网关需立即向终端下发状态变更通知。

### 2.3 Slack Gateway 稳定性增强与通知 (Slack & Gateway Resilience)
- **问题描述**：
  - Slack Socket Mode 的 Watchdog 机制与 SDK 自身的自动重连逻辑发生竞态（Fight），导致频繁断连循环。
  - 系统进行进程级优雅重启（SIGTERM）后，Gateway 恢复上线时终端没有提示。
- **功能需求**：
  - 为 Slack Watchdog 引入 60 秒宽限期（Grace Period），如果在宽限期内 SDK 自动重连成功，则 Watchdog 退出干预。
  - 捕获 SIGTERM 信号导致的重启并在恢复后下发 `♻️ Gateway online` 通知。

### 2.4 IaC 部署脚本固化 (Infrastructure as Code)
- **问题描述**：自动化发布与夜间巡检缺乏标准化的运维脚本。
- **功能需求**：
  - 提供安全的更新/推送脚本 `safe_update.sh` 和 `safe_push.sh`，具备脏工作区防呆、未跟踪文件隔离及版本退避能力。
  - 提供 `elysia-nightly-patrol.sh` 执行夜间自动化体检。

### 2.5 CLI 中间件修复 (Middleware Guard)
- **问题描述**：PluginManager 在特定初始化路径下访问 `_middleware` 会触发 `AttributeError` 导致崩溃。
- **功能需求**：通过安全访问层（`getattr`）为中间件拦截提供降级空字典处理。
