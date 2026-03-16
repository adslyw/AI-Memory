#!/bin/bash

# M3U Player Docker 部署脚本
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色定义（仅支持终端颜色）
if command -v tput >/dev/null 2>&1; then
    GREEN=$(tput setaf 2 2>/dev/null || echo "")
    RED=$(tput setaf 1 2>/dev/null || echo "")
    BLUE=$(tput setaf 4 2>/dev/null || echo "")
    NC=$(tput sgr0 2>/dev/null || echo "")
fi

# 打印带颜色的消息
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Docker 是否运行
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker 未运行或当前用户无权限"
        exit 1
    fi
}

# 构建镜像
build() {
    log_info "开始构建 Docker 镜像..."
    docker-compose build
    log_success "镜像构建完成"
}

# 启动服务
start() {
    log_info "启动 M3U Player 服务..."
    docker-compose up -d
    log_success "服务已启动"
    echo ""
    log_info "访问地址:"
    echo "  🌐 HTTP: http://localhost"
    echo "   🔧 API: http://localhost/api/data"
    echo ""
    log_info "查看日志: docker-compose logs -f"
    log_info "停止服务: $0 stop"
}

# 停止服务
stop() {
    log_info "停止 M3U Player 服务..."
    docker-compose down
    log_success "服务已停止"
}

# 重启服务
restart() {
    log_info "重启 M3U Player 服务..."
    docker-compose restart
    log_success "服务已重启"
}

# 查看日志
logs() {
    docker-compose logs -f "${@:-app}"
}

# 查看状态
status() {
    docker-compose ps
}

# 更新代码并重启
update() {
    log_info "更新代码..."
    git pull 2>/dev/null || log_info "非 git 仓库，跳过代码更新"
    
    log_info "重新构建镜像..."
    docker-compose build
    
    log_info "重启服务..."
    docker-compose up -d
    
    log_success "更新完成"
}

# 清理（删除容器、网络、未使用的镜像）
clean() {
    log_info "清理 Docker 资源..."
    docker-compose down -v
    docker image prune -f --filter "label=com.docker.compose.project=m3u-player"
    log_success "清理完成"
}

# 进入容器
shell() {
    docker-compose exec app sh
}

# 备份数据库
backup() {
    local backup_file="backup-$(date +%Y%m%d-%H%M%S).sql"
    log_info "备份数据库到 $backup_file..."
    
    if [ -f "data/m3u-player.db" ]; then
        cp "data/m3u-player.db" "backup/$backup_file" 2>/dev/null || mkdir -p backup && cp "data/m3u-player.db" "backup/$backup_file"
        log_success "备份完成: backup/$backup_file"
    else
        log_error "数据库文件不存在"
    fi
}

# 恢复数据库
restore() {
    if [ -z "$1" ]; then
        log_error "用法: $0 restore <backup-file.sql>"
        exit 1
    fi
    
    if [ ! -f "$1" ]; then
        log_error "备份文件不存在: $1"
        exit 1
    fi
    
    log_info "恢复数据库从 $1..."
    docker-compose stop app
    cp "$1" "data/m3u-player.db"
    docker-compose start app
    log_success "恢复完成"
}

# 显示帮助
help() {
    cat << EOF
M3U Player Docker 部署管理脚本

用法: $0 <命令> [参数]

命令:
  build      构建 Docker 镜像
  start      启动服务（后台运行）
  stop       停止服务
  restart    重启服务
  logs       查看日志（跟随模式）
  status     查看容器状态
  update     更新代码并重启
  clean      清理容器、网络和未使用镜像
  shell      进入应用容器 Shell
  backup     备份数据库
  restore    恢复数据库 (需要 backup 文件参数)
  help       显示此帮助信息

示例:
  $0 start          启动服务
  $0 logs app       查看应用日志
  $0 backup         备份数据库
  $0 logs nginx     查看 Nginx 日志

访问地址:
  HTTP: http://localhost
  API:  http://localhost/api/data

EOF
}

# 主程序
main() {
    check_docker
    
    case "${1:-help}" in
        build)
            build
            ;;
        start)
            start
            ;;
        stop)
            stop
            ;;
        restart)
            restart
            ;;
        logs)
            shift
            logs "$@"
            ;;
        status)
            status
            ;;
        update)
            update
            ;;
        clean)
            clean
            ;;
        shell)
            shell
            ;;
        backup)
            backup
            ;;
        restore)
            shift
            restore "$1"
            ;;
        -h|--help|help)
            help
            ;;
        *)
            log_error "未知命令: $1"
            help
            exit 1
            ;;
    esac
}

main "$@"
