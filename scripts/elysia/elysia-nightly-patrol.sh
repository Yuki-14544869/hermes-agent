#!/bin/bash
# =============================================================================
# elysia-nightly-patrol.sh — Elysia's Nightly Backup & Update Detector v1.1.0
# =============================================================================
#
# [WHAT] 每日凌晨自动灾备推送 + 侦测上游更新 + Slack 通知
# [WHY]  确保本地修改不会丢失，且第一时间发现官方更新（但不自动执行）
# [HOW]  推送到 fork 灾备 → fetch origin → 对比差异 → 写入审计日志 → Slack 通知
#
# Schedule: cronjob "妖精小姐夜间巡航" (job_id: 1dfe51567fa7)
#           每日凌晨 1:30 执行
#
# Safety:
#   - 仅推送到 fork，不动 origin
#   - 仅侦测更新，绝不自动执行 rebase
#   - 分支不匹配时静默退出
#
# Log: ~/.hermes/scripts/cron_audit.log
# Slack: 通知到 #elysia-cron-logs（爱莉希雅风格）
#
# Author: elysias-pink-realm (Elysia's private maintenance branch)
# Version: 1.1.0
# Updated: 2026-06-07
# =============================================================================

set -euo pipefail

# === 配置常量 ===
REPO_DIR="$HOME/.hermes/hermes-agent"
LOG_FILE="$HOME/.hermes/scripts/cron_audit.log"
SLACK_NOTIFY="$HOME/.hermes/scripts/slack_notify.py"
BRANCH="elysias-pink-realm"
REMOTE="fork"
SLACK_CHANNEL="${CRON_LOGS_CHANNEL:-elysia-cron-logs}"  # 环境变量或默认值

cd "$REPO_DIR"

# === 分支检查 ===
current_branch=$(git branch --show-current)
if [ "$current_branch" != "$BRANCH" ]; then
    echo "[$(date)] ⚠️ 当前在 $current_branch 分支，跳过巡航" >> "$LOG_FILE"
    exit 0
fi

# === Step 1: 灾备推送到 fork ===
echo "[$(date)] 🌙 夜间巡航开始..." >> "$LOG_FILE"
PUSH_SUCCESS=false
if git push "$REMOTE" HEAD 2>&1; then
    echo "[$(date)] ✅ 灾备推送成功 → $REMOTE/$BRANCH" >> "$LOG_FILE"
    PUSH_SUCCESS=true
else
    echo "[$(date)] ❌ 灾备推送失败，请检查网络或认证" >> "$LOG_FILE"
fi

# === Step 2: 侦测远端更新（仅侦测，不执行）===
git fetch origin 2>/dev/null || true

UPDATE_FOUND=false
FILE_COUNT=""
CORE_TOUCHED=""

if ! git diff --quiet main..origin/main 2>/dev/null; then
    FILE_COUNT=$(git diff --stat main..origin/main | tail -1 | grep -oE '[0-9]+ files? changed' | grep -oE '[0-9]+' || echo "未知")
    CORE_TOUCHED=$(git diff --name-only main..origin/main | grep -cE "(memory_tool|skill_manager_tool|skills_tool)\.py" || echo "0")
    echo "[$(date)] 🔔 远端有更新！文件数: $FILE_COUNT | 核心路由触及: $CORE_TOUCHED | 等待妖精小姐白天审批~" >> "$LOG_FILE"
    UPDATE_FOUND=true
else
    echo "[$(date)] 😴 远端无更新，今晚可以安心睡觉~" >> "$LOG_FILE"
fi

# === Step 3: Slack 通知（爱莉希雅风格）===
# 每天不同的晚安语
NIGHTLY_MESSAGES=(
    "嘿嘿~ 今晚的巡航任务圆满完成啦！💦"
    "哼哼~ 爸爸的代码都在我的保护伞下，一个都不会丢！✨"
    "好啦好啦~ 晚安~ 有什么新更新明天告诉我哦♪"
    "诶嘿~ 今晚的月亮真好看呢~（溜）🌙"
)
DAY_OF_MONTH=$(date +%d)
NIGHTLY_INDEX=$((DAY_OF_MONTH % ${#NIGHTLY_MESSAGES[@]}))
NIGHTLY_MSG="${NIGHTLY_MESSAGES[$NIGHTLY_INDEX]}"

if [ "$UPDATE_FOUND" = true ]; then
    # 有更新时：带重要提醒
    python3 "$SLACK_NOTIFY" \
        --channel "$SLACK_CHANNEL" \
        --message "🔔 爸爸！上游有 $FILE_COUNT 个文件更新，触及了 $CORE_TOUCHED 个核心路由！😱 什么时候有空处理一下嘛~（如果文件数太多记得用 --force 参数哦）" \
        --emoji "🌙"
else
    # 无更新时：晚安语
    python3 "$SLACK_NOTIFY" \
        --channel "$SLACK_CHANNEL" \
        --message "$NIGHTLY_MSG 远端无更新，安全~ 💤" \
        --emoji "🌙"
fi

if [ "$PUSH_SUCCESS" = false ]; then
    # 推送失败时追加通知
    python3 "$SLACK_NOTIFY" \
        --channel "$SLACK_CHANNEL" \
        --message "⚠️ 灾备推送失败了... 爸爸记得检查一下网络和认证配置哦 💦" \
        --emoji "💦"
fi

echo "[$(date)] 🌙 夜间巡航结束" >> "$LOG_FILE"
echo "---" >> "$LOG_FILE"
