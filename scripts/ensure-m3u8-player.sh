#!/bin/bash
# M3U8 Player 自动恢复服务脚本
# ================================

SERVICE_NAME="m3u8-player"
DATA_DIR="/home/deepnight/src/m3u-player"
COMPOSE_FILE="$DATA_DIR/docker-compose.yml"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 检查服务状态
check_service() {
    if docker ps --filter "name=$SERVICE_NAME" --format '{{.Status}}' | grep -q 'Up'; then
        return 0  # 运行中
    else
        return 1  # 未运行
    fi
}

# 启动服务
start_service() {
    log "正在启动 $SERVICE_NAME..."
    if [[ -f "$COMPOSE_FILE" ]]; then
        cd "$DATA_DIR" && docker-compose up -d
        if [[ $? -eq 0 ]]; then
            log "服务启动成功"
            return 0
        else
            log "服务启动失败"
            return 1
        fi
    else
        log "docker-compose.yml 不存在: $COMPOSE_FILE"
        return 1
    fi
}

# 主逻辑
if check_service; then
    log "服务已在运行，跳过启动"
    exit 0
else
    log "服务未运行，尝试自动恢复..."
    if start_service; then
        # 等待 10 秒后检查是否真的起来了
        sleep 10
        if check_service; then
            log "✅ 服务恢复成功"
            exit 0
        else
            log "❌ 服务启动后仍未运行"
            exit 1
        fi
    else
        log "❌ 自动恢复失败"
        exit 1
    fi
fi
