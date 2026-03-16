#!/bin/bash
# 知识同步健康检查脚本
# 用途: 验证 sync/ 目录状态和同步健康度

set -e

WORKSPACE="$HOME/.openclaw/workspace"
SYNC_DIR="$WORKSPACE/sync"
LOG_FILE="$WORKSPACE/logs/verify-sync-$(date '+%Y-%m-%d').log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_pass() {
    log "✅ PASS: $1"
    echo -e "${GREEN}✅${NC} $1"
}

check_fail() {
    log "❌ FAIL: $1"
    echo -e "${RED}❌${NC} $1"
}

check_warn() {
    log "⚠️  WARN: $1"
    echo -e "${YELLOW}⚠️${NC} $1"
}

# 开始检查
log "=== 知识同步健康检查开始 ==="
echo ""

# 1. 检查 sync/ 目录是否存在
if [ ! -d "$SYNC_DIR" ]; then
    check_fail "sync/ 目录不存在"
    exit 1
fi
check_pass "sync/ 目录存在"

# 2. 检查 .git 目录
if [ ! -d "$SYNC_DIR/.git" ]; then
    check_fail "sync/.git 不存在（不是 Git 仓库）"
    exit 1
fi
check_pass "sync/.git 存在"

# 3. 检查核心目录结构
for dir in core memory notes skills state; do
    if [ -d "$SYNC_DIR/$dir" ]; then
        check_pass "目录存在: $dir/"
    else
        check_warn "目录缺失: $dir/（可能尚未同步）"
    fi
done

# 4. 检查 Git remote 配置
cd "$SYNC_DIR"
if git remote | grep -q origin; then
    check_pass "Git remote 'origin' 已配置"
    REMOTE_URL=$(git remote get-url origin)
    log "Remote URL: $REMOTE_URL"
else
    check_fail "Git remote 'origin' 未配置"
    exit 1
fi

# 5. 检查本地修改
if git status --porcelain | grep -q .; then
    check_warn "sync/ 有未提交的本地修改"
    git status --porcelain | tee -a "$LOG_FILE"
else
    check_pass "sync/ 工作区干净（无未提交修改）"
fi

# 6. 检查与 origin/main 的状态
if git rev-parse --verify origin/main >/dev/null 2>&1; then
    LOCAL_HASH=$(git rev-parse HEAD)
    REMOTE_HASH=$(git rev-parse origin/main)

    if [ "$LOCAL_HASH" = "$REMOTE_HASH" ]; then
        check_pass "本地与远程同步（最新）"
    else
        check_warn "本地与远程存在差异"
        git log --oneline -3 | tee -a "$LOG_FILE"
    fi
else
    check_warn "remote/main 不存在（首次推送？）"
fi

# 7. 检查上次同步状态
if [ -f "$WORKSPACE/last-sync-state.json" ]; then
    log "上次同步状态文件存在"
    if command -v jq &>/dev/null; then
        LAST_SYNC=$(jq -r '.last_sync // "unknown"' "$WORKSPACE/last-sync-state.json" 2>/dev/null || echo "unknown")
        log "上次同步时间: $LAST_SYNC"
    fi
else
    check_warn "last-sync-state.json 不存在（可能未运行过同步）"
fi

# 8. 检查日志目录
if [ -d "$WORKSPACE/logs" ] && [ -w "$WORKSPACE/logs" ]; then
    check_pass "logs/ 目录可写"
else
    check_warn "logs/ 目录不可写或不存在"
fi

# 9. 检查敏感过滤（示例文件）
if [ -f "$SYNC_DIR/core/AGENTS.md" ]; then
    if grep -q "YOUR_SECRET" "$SYNC_DIR/core/AGENTS.md" 2>/dev/null; then
        check_warn "示例占位符可能残留（应已被过滤）"
    else
        check_pass "AGENTS.md 看起来正常"
    fi
fi

# 10. 检查冲突文件
CONFLICT_FILES=$(find "$SYNC_DIR" -name "*.orig" -o -name "*.冲突" -o -name "*conflict*" 2>/dev/null)
if [ -n "$CONFLICT_FILES" ]; then
    check_fail "检测到冲突文件:"
    echo "$CONFLICT_FILES" | tee -a "$LOG_FILE"
    exit 1
fi
check_pass "无冲突文件"

# 总结
log "=== 检查完成 ==="
echo ""
echo -e "${GREEN}所有关键检查通过！${NC} 同步系统健康。"
echo "查看详细日志: $LOG_FILE"

exit 0
