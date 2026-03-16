#!/bin/bash
# 知识同步状态查看脚本

WORKSPACE="$HOME/.openclaw/workspace"
SYNC_DIR="$WORKSPACE/sync"

echo "📊 知识同步状态"
echo "=================="
echo ""

if [ ! -d "$SYNC_DIR" ]; then
    echo "❌ sync/ 目录不存在"
    exit 1
fi

cd "$SYNC_DIR"

echo "📍 工作区: $SYNC_DIR"
echo ""

# Git 状态
echo "📋 Git 状态:"
echo "  分支: $(git branch --show-current)"
echo "  最新提交: $(git log --oneline -1)"
echo ""

# 远程状态
if git remote | grep -q origin; then
    echo "🌐 远程仓库: $(git remote get-url origin)"
    git fetch --quiet origin
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/main 2>/dev/null || echo "N/A")
    if [ "$LOCAL" = "$REMOTE" ]; then
        echo "  同步状态: ✅ 最新 (与 origin/main 一致)"
    else
        echo "  同步状态: ⚠️  有未拉取的更新"
        echo "  本地:  $LOCAL"
        echo "  远程:  $REMOTE"
    fi
else
    echo "  ⚠️  未配置 origin remote"
fi

echo ""

# 目录大小
echo "💾 磁盘使用:"
du -sh "$SYNC_DIR/core" 2>/dev/null || echo "  core/  不存在"
du -sh "$SYNC_DIR/memory" 2>/dev/null || echo "  memory/ 不存在"
du -sh "$SYNC_DIR/notes" 2>/dev/null || echo "  notes/  不存在"
du -sh "$SYNC_DIR/skills" 2>/dev/null || echo "  skills/ 不存在"
echo "  总计: $(du -sh "$SYNC_DIR" | cut -f1)"
echo ""

# 上次同步时间
if [ -f "$WORKSPACE/last-sync-state.json" ]; then
    if command -v jq &>/dev/null; then
        LAST_SYNC=$(jq -r '.last_sync // "未知"' "$WORKSPACE/last-sync-state.json" 2>/dev/null)
        echo "⏰ 上次同步: $LAST_SYNC"
    fi
fi

# 检查是否有待推送的提交
PENDING_COMMITS=$(git log --oneline @{u}..HEAD 2>/dev/null | wc -l)
if [ "$PENDING_COMMITS" -gt 0 ]; then
    echo "📤 待推送提交: $PENDING_COMMITS 个"
else
    echo "📤 待推送提交: 0"
fi

# 检查是否有待拉取的提交
PENDING_PULLS=$(git log --oneline HEAD..@{u} 2>/dev/null | wc -l)
if [ "$PENDING_PULLS" -gt 0 ]; then
    echo "📥 待拉取提交: $PENDING_PULLS 个"
else
    echo "📥 待拉取提交: 0"
fi

echo ""
echo "✅ 系统正常"
