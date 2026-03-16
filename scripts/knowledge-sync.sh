#!/bin/bash
# 多 Agent 知识同步引擎
# 功能: 双向同步本地工作区与共享知识库 (自动过滤敏感信息)

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
SYNC_DIR="$WORKSPACE/sync"
LOG_FILE="$WORKSPACE/logs/sync-$(date '+%Y-%m-%d').log"
STATE_FILE="$WORKSPACE/last-sync-state.json"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    log "INFO: $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    log "WARN: $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR: $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS: $1"
}

# 检查前置条件
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

# 更新排除规则（确保敏感文件不被跟踪）
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
        # 从模板创建
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
        # 确保关键规则存在
        for pattern in "${required_patterns[@]}"; do
            if ! grep -Fxq "$pattern" "$gitignore" 2>/dev/null; then
                echo "$pattern" >> "$gitignore"
                info "添加排除规则: $pattern"
            fi
        done
    fi
}

# 脱敏函数: 过滤文件中的敏感信息
sanitize_file() {
    local file="$1"
    local tmp="${file}.sanitized"

    # 创建脱敏副本
    cp "$file" "$tmp"

    # 常见敏感模式替换
    sed -i -E \
        -e 's/(password|passwd|pwd|secret|token|api_key|apikey)[=:][[:space:]]*[^[:space:]]+/\\1=[REDACTED]/Ig' \
        -e 's/(AKIA|sk-|ghp_|glpat-)[A-Za-z0-9_-]{20,}/[REDACTED]/g' \
        -e 's/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[REDACTED-IP]/g' \
        -e 's/(mongodb|mysql|postgres|redis):\/\/[^@]+@/[REDACTED-CONNECTION]\//g' \
        "$tmp" 2>/dev/null || true

    echo "$tmp"
}

# 复制文件到 sync/（带脱敏）
sync_files() {
    info "开始文件同步..."

    # 确保目标目录存在
    mkdir -p "$SYNC_DIR/core" "$SYNC_DIR/memory" "$SYNC_DIR/notes/areas" "$SYNC_DIR/skills" "$SYNC_DIR/state"

    # 核心配置文件（脱敏后复制）
    local core_files=(
        "SOUL.md:core/"
        "USER.md:core/"
        "AGENTS.md:core/"
        "HEARTBEAT.md:core/"
        "ONBOARDING.md:core/"
    )

    for mapping in "${core_files[@]}"; do
        local src="${mapping%%:*}"
        local dest_dir="${mapping#*:}"
        local src_path="$WORKSPACE/$src"
        local dest_path="$SYNC_DIR/$dest_dir$(basename "$src")"

        if [ -f "$src_path" ]; then
            local sanitized
            sanitized=$(sanitize_file "$src_path")
            cp "$sanitized" "$dest_path"
            rm -f "$sanitized"
            info "已同步: $src → $dest_dir"
        else
            warn "源文件不存在: $src_path"
        fi
    done

    # 记忆文件（每日笔记 + MEMORY.md）
    if [ -d "$WORKSPACE/memory" ]; then
        rsync -a --delete "$WORKSPACE/memory/" "$SYNC_DIR/memory/" 2>/dev/null || true
        info "已同步 memory/ 目录"
    fi

    # 笔记文件
    if [ -d "$WORKSPACE/notes" ]; then
        rsync -a --delete "$WORKSPACE/notes/" "$SYNC_DIR/notes/" 2>/dev/null || true
        info "已同步 notes/ 目录"
    fi

    # 技能文档（只读共享）
    if [ -d "$WORKSPACE/skills" ]; then
        # 只复制 SKILL.md 和 README.md，不复制 scripts/（可能包含敏感逻辑）
        find "$WORKSPACE/skills" -name "SKILL.md" -o -name "README.md" | while read -r skill_doc; do
            local rel_path="${skill_doc#$WORKSPACE/}"
            local dest_path="$SYNC_DIR/$rel_path"
            mkdir -p "$(dirname "$dest_path")"
            cp "$skill_doc" "$dest_path"
        done
        info "已同步 skills/ 文档"
    fi

    # 状态文件（仅公开字段）
    if [ -f "$WORKSPACE/star-office-sync.json" ]; then
        # 过滤敏感字段后复制
        jq 'del(.token, .secret, .apiKey, .password)' "$WORKSPACE/star-office-sync.json" > "$SYNC_DIR/state/star-office-state.json" 2>/dev/null || true
        info "已同步 star-office 状态（脱敏）"
    fi
}

# 执行 Git 操作
git_sync() {
    cd "$SYNC_DIR"

    info "=== Git 同步开始 ==="

    # 配置 Git（如果尚未配置）
    if [ -z "$(git config user.name)" ]; then
        git config user.name "OpenClaw Agent"
        git config user.email "agent@openclaw.local"
    fi

    # 拉取远程变更
    info "正在拉取远程变更..."
    if git fetch origin; then
        # 尝试合并（如果本地有提交）
        if git rev-parse --verify HEAD >/dev/null 2>&1; then
            if git merge --ff-only origin/main 2>/dev/null; then
                info "已合并远程变更"
            elif git merge origin/main 2>&1 | grep -q "Automatic merge failed"; then
                warn "检测到冲突！需要手动解决"
                echo "冲突文件:"
                git diff --name-only --diff-filter=U | tee -a "$LOG_FILE"
                # 创建冲突标记文件
                touch "$SYNC_DIR/.conflict-detected"
                error "同步失败：有冲突需解决"
                return 1
            else
                info "合并成功"
            fi
        else
            git checkout -b main origin/main 2>/dev/null || git checkout main
            info "已切换到 origin/main"
        fi
    else
        warn "git fetch 失败，检查网络和远程配置"
        return 1
    fi

    # 添加新的/修改的文件
    git add -A 2>/dev/null || true

    # 提交（如果有变更）
    if git diff --cached --quiet; then
        info "没有本地变更需要推送"
    else
        git commit -m "Auto-sync from $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null || true
        if git push origin main; then
            success "已推送变更到远程"
        else
            warn "推送失败（可能远程有更新，下次 pull 会解决）"
        fi
    fi

    info "=== Git 同步完成 ==="
}

# 保存同步状态
save_state() {
    local state="{
  \"last_sync\": \"$(date -Iseconds)\",
  \"status\": \"success\",
  \"host\": \"$(hostname)\",
  \"workspace\": \"$WORKSPACE\"
}"
    echo "$state" > "$STATE_FILE"
    info "状态已保存: $STATE_FILE"
}

# 主流程
main() {
    log "=== 知识同步开始 ==="

    check_prerequisites
    update_gitignore
    sync_files
    git_sync

    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        save_state
        success "知识同步完成！"
        log "=== 同步成功 ==="
        exit 0
    else
        error "知识同步失败（exit code $exit_code）"
        log "=== 同步失败 ==="
        exit $exit_code
    fi
}

main "$@"
