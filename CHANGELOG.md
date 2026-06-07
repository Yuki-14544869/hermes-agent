# 变更日志 (Changelog)

## [v0.16.0-elysia.0.1.0] - 2026-06-07

### Added (新增功能)
- **Router**: 强化记忆与技能的路由约束，彻底解决过程性知识污染持久化状态的问题。

## [v0.16.0-elysia.0.2.0] - 2026-06-07

### Added (新增功能)
- **Search**: 增加 SearXNG -> Brave Search -> DuckDuckGo 的容灾降级功能，并在降级发生时立刻通过 Socket 向 UI 广播状态转移通知。

## [v0.16.0-elysia.0.3.0] - 2026-06-07

### Added (新增功能)
- **Gateway**: 为 Slack 连接保活机制引入 60 秒优雅退让宽限期，避免与 SDK 原生重连机制发生竞态。
- **Gateway**: 捕获 SIGTERM 重启信号，触发拉起后广播 ♻️ Gateway online。

## [v0.16.0-elysia.0.3.1] - 2026-06-07

### Fixed (问题修复)
- **Middleware**: 修复 `PluginManager._middleware` 初始化时序错乱时的属性访问奔溃问题。
