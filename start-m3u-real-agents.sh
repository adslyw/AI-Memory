#!/bin/bash
# M3U Player 并行任务 - 已修复

set -euo pipefail

PROJECT="/home/deepnight/.openclaw/workspace/projects/m3u-player"
BASE_WORK="/home/deepnight/.openclaw/workspace/tmp-m3u-agents"
SOCKET="/tmp/clawdbot-tmux-sockets/m3u-agent-run.sock"

mkdir -p "$BASE_WORK"
tmux -S "$SOCKET" kill-server 2>/dev/null || true

echo "🚀 M3U Player 并行改进任务"
echo "主仓库: $PROJECT"
echo ""

# 1. 为主分支创建三个临时克隆（模拟 worktrees）
for agent in forge pixel kernel; do
  WORKDIR="$BASE_WORK/$agent"
  if [[ -d "$WORKDIR/.git" ]]; then
    echo "♻️  更新: $agent"
    (cd "$WORKDIR" && git pull) 2>/dev/null || true
  else
    echo "📦 克隆: $agent"
    git clone "$PROJECT" "$WORKDIR" 2>/dev/null
  fi
done

# 2. 创建分支
(cd "$BASE_WORK/forge" && git checkout -b forge-search 2>/dev/null || true)
(cd "$BASE_WORK/pixel" && git checkout -b pixel-dark 2>/dev/null || true)
(cd "$BASE_WORK/kernel" && git checkout -b kernel-docker 2>/dev/null || true)

# 3. 启动 tmux sessions
echo ""
echo "🤖 启动 agents..."

# Forge: 代码质量检查
tmux -S "$SOCKET" new -d -s agent-forge -n work
tmux -S "$SOCKET" send-keys -t agent-forge "cd $BASE_WORK/forge && echo '🔧 Forge: 代码质量检查' && npm run lint 2>&1 | head -50" Enter
echo "  ✅ agent-forge (forge-search)"

# Pixel: 构建项目（模拟 UI 工作）
tmux -S "$SOCKET" new -d -s agent-pixel -n work
tmux -S "$SOCKET" send-keys -t agent-pixel "cd $BASE_WORK/pixel && echo '🎨 Pixel: UI 构建测试' && npm run build 2>&1 | tail -30" Enter
echo "  ✅ agent-pixel (pixel-dark)"

# Kernel: Docker 镜像检查
tmux -S "$SOCKET" new -d -s agent-kernel -n work
tmux -S "$SOCKET" send-keys -t agent-kernel "cd $BASE_WORK/kernel && echo '⚙️ Kernel: Docker 检查' && docker images | grep m3u" Enter
echo "  ✅ agent-kernel (kernel-docker)"

echo ""
echo "✅ 所有 agents 运行中"
echo ""
echo "📊 监控:"
echo "  tmux -S $SOCKET list-sessions"
echo "  tmux -S $SOCKET attach -t agent-forge   # 查看 Forge 输出"
echo "  tmux -S $SOCKET capture-pane -p -t agent-forge:0.0 -S -50   # 快照"
echo ""
echo "🛑 停止全部: tmux -S $SOCKET kill-server"
echo ""
echo "💡 工作目录:"
echo "  Forge:  $BASE_WORK/forge/forge-search"
echo "  Pixel:  $BASE_WORK/pixel/pixel-dark"
echo "  Kernel: $BASE_WORK/kernel/kernel-docker"
echo ""
