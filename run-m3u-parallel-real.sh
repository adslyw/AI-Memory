#!/bin/bash
# M3U Player - 真实并行任务演示
# 让 Forge、Pixel、Kernel 在不同工作目录并行执行不同的开发任务

set -euo pipefail

# 配置
SOCKET_DIR="${TMPDIR:-/tmp}/clawdbot-tmux-sockets"
SOCKET="${SOCKET_DIR}/m3u-real-agents.sock"
TASK_BASE="/home/deepnight/.openclaw/workspace/"

mkdir -p "$SOCKET_DIR"
tmux -S "$SOCKET" kill-server 2>/dev/null || true

echo "🚀 启动 M3U Player 真实并行开发任务"
echo "Socket: $SOCKET"
echo ""

# 定义 agents: workdir : session_name : task_script : description
AGENTS=(
  "/home/deepnight/.openclaw/workspace/projects/m3u-player-worktrees/forge-search:m3u-forge:${TASK_BASE}forge-task.sh:'Forge - 搜索功能开发'"
  "/home/deepnight/.openclaw/workspace/projects/m3u-player-worktrees/pixel-dark:m3u-pixel:${TASK_BASE}pixel-task.sh:'Pixel - 暗色主题实现'"
  "/home/deepnight/.openclaw/workspace/projects/m3u-player-worktrees/kernel-docker:m3u-kernel:${TASK_BASE}kernel-task.sh:'Kernel - Docker 优化'"
)

echo "🤖 启动 agents..."
for agent_def in "${AGENTS[@]}"; do
  IFS=':' read -r workdir session task_script desc <<< "$agent_def"

  # 检查工作目录
  if [[ ! -d "$workdir" ]]; then
    echo "  ⚠️  跳过 $desc (工作目录不存在: $workdir)"
    continue
  fi

  # 创建 tmux 会话
  tmux -S "$SOCKET" new-session -d -s "$session" -n work

  # 发送任务脚本
  tmux -S "$SOCKET" send-keys -t "$session":0.0 "clear" Enter
  tmux -S "$SOCKET" send-keys -t "$session":0.0 "echo '========================================" Enter
  tmux -S "$SOCKET" send-keys -t "$session":0.0 "echo '$desc'" Enter
  tmux -S "$SOCKET" send-keys -t "$session":0.0 "echo '========================================" Enter
  tmux -S "$SOCKET" send-keys -t "$session":0.0 "cd $workdir && bash '$task_script'" Enter

  echo "  ✅ $session - $desc"
done

echo ""
echo "✨ 所有 agents 已启动，正在并行工作！"
echo ""
echo "📊 监控命令:"
echo "  查看所有会话: tmux -S $SOCKET list-sessions"
echo ""
echo "查看某个 agent 的完整输出（实时）:"
echo "  tmux -S $SOCKET attach -t m3u-forge"
echo "  tmux -S $SOCKET attach -t m3u-pixel"
echo "  tmux -S $SOCKET attach -t m3u-kernel"
echo "  退出监控: Ctrl+b d"
echo ""
echo "获取输出快照（不 attach）:"
echo "  tmux -S $SOCKET capture-pane -p -t m3u-forge:0.0 -S -100"
echo ""
echo "检查任务状态（是否在运行）:"
echo "  tmux -S $SOCKET list-panes -a -F '#{session_name} #{pane_active}' | grep '^m3u-.* 1'"
echo ""
echo "🛑 停止所有 agents:"
echo "  tmux -S $SOCKET kill-server"
echo ""
echo "💡 提示:"
echo "  - 每个 agent 在独立工作目录，使用独立 git 仓库"
echo "  - 任务完成后会显示 ✅ 完成标志"
echo "  - 你可以随时 attach 查看进度，或 capture-pane 获取快照"
echo ""

# 显示会话列表
sleep 1
echo "当前运行的 tmux 会话:"
tmux -S "$SOCKET" list-sessions 2>/dev/null || echo "  (无)"

echo ""
echo "🎯 试试这个命令查看 forge 的最新输出:"
echo "  tmux -S $SOCKET capture-pane -p -t m3u-forge:0.0 -S -20 | tail -10"
