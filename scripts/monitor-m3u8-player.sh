#!/bin/bash
# M3U Player 服务监控脚本
# ================================

SERVICE_NAME="m3u-player-app"
APP_NAME="M3U Player"
WORKSPACE="/home/deepnight/.openclaw/workspace"
LOG_FILE="$WORKSPACE/monitor-$(date +%Y-%m-%d).log"
STATE_FILE="$WORKSPACE/monitor-state.json"
WEBHOOK_URL=""

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] OK: $1${NC}" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}" | tee -a "$LOG_FILE"
}

# 加载状态
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE" | jq -r '.last_check, .uptime_days, .last_notification // empty' 2>/dev/null || echo "{}"
    else
        echo "{}"
    fi
}

# 保存状态
save_state() {
    local uptime_days=$1
    local last_check=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "{\"last_check\":\"$last_check\",\"uptime_days\":$uptime_days}" > "$STATE_FILE"
}

# 检查服务状态
check_service() {
    local status="down"
    local response_time=0
    local status_code=0

    # 检查容器是否运行
    if docker ps --filter "name=$SERVICE_NAME" --format '{{.Names}}' | grep -q "$SERVICE_NAME"; then
        status="running"

        # 检查 HTTP 端点
        local start_time=$(date +%s%N)
        local http_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3456/api/data" 2>/dev/null || echo "000")
        local end_time=$(date +%s%N)
        response_time=$(( (end_time - start_time) / 1000000 ))

        if [[ "$http_status" == "200" ]]; then
            status="healthy"
        else
            status="unhealthy (HTTP $http_status)"
        fi
    else
        status="stopped"
    fi

    echo "$status:$response_time:$http_status"
}

# 获取访问日志统计（如果存在）
get_stats() {
    local data_dir="/home/deepnight/src/m3u-player/data"
    local db_file="$data_dir/m3u-player.db"

    if [[ -f "$db_file" ]]; then
        # 简单统计：数据库大小和修改时间
        local db_size=$(du -h "$db_file" | cut -f1)
        local db_modified=$(stat -c %y "$db_file" 2>/dev/null || stat -f %Sm "$db_file" 2>/dev/null)
        echo "DB Size: $db_size, Modified: $db_modified"
    else
        echo "No database found"
    fi
}

# 计算运行天数
calculate_uptime() {
    local container_info=$(docker inspect "$SERVICE_NAME" 2>/dev/null | jq -r '.[0].State.StartedAt // empty' 2>/dev/null)
    if [[ -n "$container_info" ]]; then
        local start_timestamp=$(date -d "$container_info" +%s)
        local now_timestamp=$(date +%s)
        local uptime_seconds=$((now_timestamp - start_timestamp))
        local uptime_days=$((uptime_seconds / 86400))
        echo "$uptime_days"
    else
        echo "0"
    fi
}

# 发送通知（可选）
send_notification() {
    local status=$1
    local message=$2

    if [[ -n "$WEBHOOK_URL" ]]; then
        curl -s -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"$APP_NAME 监控: $status\n$message\"}" > /dev/null 2>&1
    fi
}

# 主监控函数
main() {
    log "=== 开始监控检查 ==="

    # 1. 服务状态检查
    local check_result=$(check_service)
    IFS=':' read -r status response_time http_status <<< "$check_result"

    case "$status" in
        "healthy")
            success "服务健康运行 (响应时间: ${response_time}ms)"
            ;;
        "running")
            info "容器运行但HTTP异常 (状态码: $http_status, 响应时间: ${response_time}ms)"
            error "HTTP服务异常"
            ;;
        "stopped")
            error "服务已停止"
            send_notification "DOWN" "服务已停止，请检查容器"
            ;;
        *)
            error "服务状态异常: $status"
            send_notification "UNHEALTHY" "服务异常: $status"
            ;;
    esac

    # 2. 运行时间统计
    local uptime_days=$(calculate_uptime)
    local state=$(load_state)
    local prev_uptime=$(echo "$state" | jq -r '.uptime_days // 0' 2>/dev/null)

    if [[ "$uptime_days" -gt "$prev_uptime" ]]; then
        info "服务已连续运行 $uptime_days 天"
    fi

    save_state "$uptime_days"

    # 3. 数据统计
    local stats=$(get_stats)
    info "数据状态: $stats"

    # 4. 资源检查（可选）
    local disk_usage=$(df -h "$(pwd)" | tail -1 | awk '{print $5}' | tr -d '%')
    if [[ "$disk_usage" -gt 90 ]]; then
        warning="磁盘使用率 ${disk_usage}% 超过90%"
        error "$warning"
        send_notification "WARNING" "$warning"
    else
        info "磁盘使用率: ${disk_usage}%"
    fi

    log "=== 监控检查完成 ==="

    # 输出摘要
    echo ""
    echo "========== 监控摘要 =========="
    echo "服务状态: $status"
    echo "HTTP状态码: $http_status"
    echo "响应时间: ${response_time}ms"
    echo "运行天数: $uptime_days"
    echo "数据状态: $stats"
    echo "磁盘使用: ${disk_usage}%"
    echo "==============================="
}

# 执行
main
