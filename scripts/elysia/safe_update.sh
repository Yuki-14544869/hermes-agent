#!/bin/bash
# =============================================================================
# safe_update.sh — Elysia's Deterministic Safe Update Script v2.0.0
# =============================================================================
#
# [WHAT] 将上游 (origin/main) 更新 rebase 到 elysias-pink-realm 分支
# [WHY]  确保自定义 patch 永远在最新上游之上，历史保持线性
# [HOW]  fetch → sync main → rebase origin/main → 验证 → push
#
# 工作流图:
#   upstream/main ──fetch──→ 本地 main ──rebase──→ elysias-pink-realm
#                                                  ↑ 你的 patch 永远在栈顶
#
# Usage:
#   ./safe_update.sh              # 完整更新流程
#   ./safe_update.sh --force      # 跳过文件数门控（大型更新时使用）
#
# Exit codes:
#   0 — 更新成功
#   1 — 被门控拦截或 rebase 冲突（已自动回滚）
#
# Author: elysias-pink-realm
# Version: 2.0.0
# Updated: 2026-06-07
# =============================================================================

set -euo pipefail

# === 配置常量 ===
REPO_DIR="$HOME/.hermes/hermes-agent"
CUSTOM_BRANCH="elysias-pink-realm"
FORK_REMOTE="fork"
ORIGIN_REMOTE="origin"
MAX_FILES=200  # v2: 提高阈值，上游一天就可能超过30个文件

# === 参数解析 ===
FORCE_MODE=false
for arg in "$@"; do
    case "$arg" in
        --force) FORCE_MODE=true ;;
    esac
done

# === 辅助函数 ===
log_info()  { echo "[SafeUpdate] $*"; }
log_error() { echo "[SafeUpdate] ERROR: $*"; }

# === Step 0: 前置检查 ===
cd "$REPO_DIR" || { log_error "无法进入仓库目录 $REPO_DIR"; exit 1; }

# 修复 detached HEAD（如果存在）
current_branch=$(git branch --show-current 2>/dev/null || echo "")
if [ -z "$current_branch" ]; then
    log_info "检测到 detached HEAD，正在恢复到 $CUSTOM_BRANCH ..."
    git checkout "$CUSTOM_BRANCH"
    current_branch=$(git branch --show-current)
fi

if [ "$current_branch" != "$CUSTOM_BRANCH" ]; then
    log_error "当前在 [$current_branch] 分支，预期 [$CUSTOM_BRANCH]，拒绝更新"
    log_error "请先执行: git checkout $CUSTOM_BRANCH"
    exit 1
fi

log_info "当前分支: $current_branch ✓"

# === Step 1: 获取上游情报 ===
log_info "正在获取上游更新..."
git fetch "$ORIGIN_REMOTE" main
git fetch "$FORK_REMOTE" "$CUSTOM_BRANCH" 2>/dev/null || true

# 同步本地 main 指针到上游最新
git branch -f main "$ORIGIN_REMOTE/main"
log_info "本地 main 已同步到 $ORIGIN_REMOTE/main"

# 同步远端 fork 的 main
log_info "正在同步 fork 仓库的 main 分支..."
git push "$FORK_REMOTE" main:main 2>/dev/null || log_error "同步 fork/main 失败，请检查网络或权限"

# === Step 2: 分析变更 ===
BEHIND_COUNT=$(git rev-list --count "$CUSTOM_BRANCH".."$ORIGIN_REMOTE/main" 2>/dev/null || echo "0")
log_info "落后上游: $BEHIND_COUNT 个 commit"

if [ "$BEHIND_COUNT" -eq 0 ]; then
    log_info "✅ 已经是最新，无需更新"
    exit 0
fi

# === Step 3: 防爆门控 ===
if [ "$FORCE_MODE" = false ]; then
    UPDATE_FILES=$(git diff --name-only "$CUSTOM_BRANCH".."$ORIGIN_REMOTE/main" | wc -l | tr -d ' ')
    log_info "上游变更文件数: $UPDATE_FILES / 阈值: $MAX_FILES"

    if [ "$UPDATE_FILES" -gt "$MAX_FILES" ]; then
        log_error "官方更新文件超过 ${MAX_FILES} 个（实际: ${UPDATE_FILES}），判定为大型更新"
        log_error "使用 --force 参数跳过门控，或人工审查后再决定"
        echo ""
        echo "---CHANGE_PREVIEW_START---"
        git log --oneline "$CUSTOM_BRANCH".."$ORIGIN_REMOTE/main" | head -20
        echo "... (共 $BEHIND_COUNT 个 commit)"
        echo "---CHANGE_PREVIEW_END---"
        exit 1
    fi

    # 检查自定义 patch 涉及的文件是否被上游修改
    CONFLICT_FILES=$(git diff --name-only "$CUSTOM_BRANCH".."$ORIGIN_REMOTE/main" | \
        grep -E "(memory_tool|web_tools|model_tools|toolsets)\\.py" || true)
    if [ -n "$CONFLICT_FILES" ]; then
        log_info "⚠️ 上游修改了与你 patch 相关的文件:"
        echo "$CONFLICT_FILES"
        log_info "将继续 rebase，如果有冲突会自动回滚"
    fi
fi

# === Step 4: 安全变基 ===
log_info "开始 rebase 到 $ORIGIN_REMOTE/main 之上..."

# 记录当前 HEAD 以便回滚和对比
PRE_REBASE_HEAD=$(git rev-parse HEAD)

if ! git rebase "$ORIGIN_REMOTE/main"; then
    # rebase 失败，自动回滚
    git rebase --abort 2>/dev/null || true
    log_error "Rebase 冲突，已自动回滚到变基前状态"
    log_error "当前 HEAD: $(git rev-parse --short HEAD)"
    echo ""
    echo "---CONFLICT_FILES---"
    git diff --name-only --diff-filter=U 2>/dev/null || echo "(冲突文件已在 abort 后清除)"
    echo "---CONFLICT_FILES_END---"
    exit 1
fi

# === Step 5: 验证结果 ===
POST_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ -z "$POST_BRANCH" ]; then
    log_error "rebase 后进入 detached HEAD！正在修复..."
    git checkout "$CUSTOM_BRANCH"
    POST_BRANCH=$(git branch --show-current)
fi

if [ "$POST_BRANCH" != "$CUSTOM_BRANCH" ]; then
    log_error "rebase 后分支异常: $POST_BRANCH（预期: $CUSTOM_BRANCH）"
    exit 1
fi

# 验证自定义 patch 仍在栈顶
LOCAL_PATCHES=$(git log --oneline "$ORIGIN_REMOTE/main"..HEAD | head -20)
PATCH_COUNT=$(git rev-list --count "$ORIGIN_REMOTE/main"..HEAD)
PRE_PATCH_COUNT=$(git rev-list --count "$ORIGIN_REMOTE/main".."$PRE_REBASE_HEAD")
log_info "自定义 patch 数量: $PATCH_COUNT（rebase 前: $PRE_PATCH_COUNT）"

if [ "$PATCH_COUNT" -eq 0 ]; then
    log_error "⚠️ 警告: rebase 后没有自定义 patch 了！可能丢失了修改"
    log_error "pre-rebase HEAD: $PRE_REBASE_HEAD"
    exit 1
fi

if [ "$PATCH_COUNT" -ne "$PRE_PATCH_COUNT" ]; then
    log_error "⚠️ 警告: rebase 后 patch 数量变化！($PRE_PATCH_COUNT → $PATCH_COUNT)"
    log_error "可能有 patch 被上游覆盖或被 rebase 丢弃"
    echo ""
    echo "---PATCH_DIFF_START---"
    echo "rebase 前的 patch:"
    git log --oneline "$ORIGIN_REMOTE/main".."$PRE_REBASE_HEAD"
    echo ""
    echo "rebase 后的 patch:"
    git log --oneline "$ORIGIN_REMOTE/main"..HEAD
    echo "---PATCH_DIFF_END---"
fi

# === Step 6: 输出结果 ===
log_info "✅ 更新成功！提交历史线性完整。"
echo ""
echo "---UPDATE_LOG_START---"
echo "📊 更新摘要:"
echo "  落后: $BEHIND_COUNT → 0"
echo "  自定义 patch: $PATCH_COUNT 个（栈顶）"
echo "  rebase 前 HEAD: $(git rev-parse --short "$PRE_REBASE_HEAD")"
echo "  rebase 后 HEAD: $(git rev-parse --short HEAD)"
echo ""
echo "🔖 自定义 patch (最新在上):"
git log --oneline "$ORIGIN_REMOTE/main"..HEAD
echo ""
echo "📦 上游新 commit:"
git log --oneline "$PRE_REBASE_HEAD".."$ORIGIN_REMOTE/main" | head -30
echo "---UPDATE_LOG_END---"

echo ""
if [ "$PATCH_COUNT" -eq "$PRE_PATCH_COUNT" ]; then
    log_info "✨ Rebase 完美执行，自动推送到 $FORK_REMOTE ..."
    git push "$FORK_REMOTE" "$CUSTOM_BRANCH" --force-with-lease
else
    log_info "⚠️ Patch 数量发生变化，跳过自动推送。请人工检查确认后执行:"
    log_info "git push $FORK_REMOTE $CUSTOM_BRANCH --force-with-lease"
fi
