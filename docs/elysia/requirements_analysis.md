# 需求分析说明书 (Requirements Analysis)

## [v0.16.0-elysia.0.1.0] - 2026-06-07

### 1. 强路由约束与过程性知识拦截 (Memory/Skill Routing)
- **问题描述**：Agent 存在将“多步操作流程”、“格式规范”等过程性知识错误写入持久化事实记忆（Memory）的问题，导致上下文污染。
- **功能需求**：
  - 修改 `memory_tool`、`skill_manager_tool` 和 `skills_tool` 的系统提示语（Prompt/Schema）。
  - 强制性区分“声明式事实（如用户操作系统、偏好）”与“过程性知识（如代码规范、多步工作流）”。
  - 明确指令：过程性知识必须存入 Skill，事实性知识存入 Memory。
