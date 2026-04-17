#!/bin/bash
# 多 Agent 知识同步引擎
# 功能: 双向同步本地工作区与共享知识库 (自动过滤敏感信息)

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
SYNC_DIR="$WORKSPACE/sync"
LOG_FILE="$WORKSPACE/logs/sync-$(date '+%Y-%m-%d').log"
STATE_FILE="$WORKSPACE/last-sync-state.json"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
    log "INFO: $1"
}

warn() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
    log "WARN: $1"
}

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
    log "ERROR: $1"
}

success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
    log "SUCCESS: $1"
}

check_prerequisites() {
    if [ ! -d "$SYNC_DIR/.git" ]; then
        error "sync/ 不是 Git 仓库，请先克隆或初始化"
        exit 1
    fi

    if ! command -v git &>/dev/null; then
        error "Git 未安装"
        exit 1
    fi

    if [ ! -w "$WORKSPACE" ]; then
        error "工作区不可写: $WORKSPACE"
        exit 1
    fi
}

update_gitignore() {
    local gitignore="$SYNC_DIR/.gitignore"
    local required_patterns=(
        ".env*"
        "*.key"
        "*.pem"
        "credentials/"
        "secrets/"
        "local/"
        "working-buffer.md"
        "*.orig"
        "*conflict*"
    )

    if [ ! -f "$gitignore" ]; then
        cat > "$gitignore" <<'EOF'
# 敏感信息自动排除
.env*
*.key
*.pem
credentials/
secrets/
local/
working-buffer.md
*.orig
*conflict*
*.log
EOF
        info "已创建 .gitignore (默认规则)"
    else
        for pattern in "${required_patterns[@]}"; do
            if ! grep -Fxq "$pattern" "$gitignore" 2>/dev/null; then
                echo "$pattern" >> "$gitignore"
                info "添加排除规则: $pattern"
            fi
        done
    fi
}

sanitize_file() {
    local file="$1"
    local tmp="${file}.sanitized"

    cp "$file" "$tmp"

    sed -i -E \
        -e 's/(password|passwd|pwd|secret|token|api_key|apikey)[=:][[:space:]]*[^[:space:]]+/\\1=[REDACTED]/Ig' \
        -e 's/(AKIA|sk-|ghp_|glpat-)[A-Za-z0-9_-]{20,}/[REDACTED]/g' \
        -e 's/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[REDACTED-IP]/g' \
        -e 's|(mongodb|mysql|postgres|redis)://[^@]+@|[REDACTED-CONNECTION]/|g' \
        "$tmp" 2>/dev/null || true

    echo "$tmp"
}

sync_files() {
    info "开始文件同步..."

    mkdir -p "$SYNC_DIR/core" "$SYNC_DIR/memory" "$SYNC_DIR/notes/areas" "$SYNC_DIR/skills" "$SYNC_DIR/state"

    for mapping in \
        "SOUL.md:core/" \
        "USER.md:core/" \
        "AGENTS.md:core/" \
        "HEARTBEAT.md:core/" \
        "ONBOARDING.md:core/"; do
        src="${mapping%%:*}"
        dir="${mapping#*:}"

        if [ -f "$WORKSPACE/$src" ]; then
            sanitized=$(sanitize_file "$WORKSPACE/$src")
            cp "$sanitized" "$SYNC_DIR/$dir$(basename "$src")"
            rm -f "$sanitized"
            info "已同步: $src"
        else
            warn "源文件不存在: $WORKSPACE/$src"
        fi
    done

    if [ -d "$WORKSPACE/memory" ]; then
        rsync -a --delete "$WORKSPACE/memory/" "$SYNC_DIR/memory/" 2>/dev/null || true
        info "已同步 memory/ 目录"
    fi

    if [ -d "$WORKSPACE/notes" ]; then
        rsync -a --delete "$WORKSPACE/notes/" "$SYNC_DIR/notes/" 2>/dev/null || true
        info "已同步 notes/ 目录"
    fi

    if [ -d "$WORKSPACE/skills" ]; then
        find "$WORKSPACE/skills" -name 'SKILL.md' -o -name 'README.md' | while read -r skill_doc; do
            rel_path="${skill_path#$WORKSPACE/}"
            dest_path="$SYNC_DIR/$rel_path"
            mkdir -p "$(dirname "$dest_path")"
            cp "$skill_doc" "$dest_path"
        done
        info "已同步 skills/ 文档"
    fi

    if [ -f "$WORKSPACE/star-office-sync.json" ]; then
        jq 'del(.token, .secret, .apiKey, .password)' "$WORKSPACE/star-office-sync.json" > "$SYNC_DIR/state/star-office-state.json" 2>/dev/null || true
        info "已同步 star-office 状态（脱敏）"
    fi
}

cd "$SYNC_DIR"

info "=== Git 同步开始 ==="

if [ -z "$(git config user.name)" ]; then
    git config user.name "OpenClaw Agent"
    git config user.email "agent@openclaw.local"
fi

git fetch origin || {
    warn "git fetch 失败"
    exit 1
}

if git rev-parse --verify HEAD >/dev/null 2>&1; then
    if git merge --ff-only origin/main 2>/dev/null; then
        info "已合并远程变更"
    elif git merge origin main 2>&1 | grep -q "Automatic merge failed"; then
        warn "检测到冲突！需要手动解决"
        echo "冲突文件:"
        git diff --name-only --diff-filter=U | tee -a "$LOG_FILE"
        touch "$SYNC_DIR/.conflict-detected"
        error "同步失败：有冲突需解决"
        exit 1
    else
        info "合并成功"
    fi
else
    git checkout -b main origin/main
    info "已切换到 origin/main"
fi

git add -A

if ! git diff --cached --quiet; then
    git commit -m "Auto-sync from $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')"
    if git push origin main; then
        success "已推送变更到远程"
    else
        warn "推送失败（可能远程有更新）"
    fi
else
    info "没有本地变更需要推送"
fi

info "=== Git 同步完成 ==="

if [ -f "$STATE_FILE" ]; then
    jq 'del(.token, .secret, .apiKey, .password)' "$WORKSPACE/star-office-sync.json" > "$SYNC_DIR/state/star-office-state.json" 2>/dev/null || true
fi

success "知识同步完成！"
log "=== 同步成功 ==="
exit 0