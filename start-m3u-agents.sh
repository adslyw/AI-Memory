#!/bin/bash
# 快速启动 M3U Player 并行改进（修正版）

set -euo pipefail

SOCKET="/tmp/clawdbot-tmux-sockets/m3u-player-agents.sock"
WORKTREE_BASE="/home/deepnight/.openclaw/workspace/projects/m3u-player-worktrees"

tmux -S "$SOCKET" kill-server 2>/dev/null || true

# Agents 配置：会话名 : 目录 : 任务描述 : 命令
declare -A AGENTS
AGENTS["forge"]="$WORKTREE_BASE/forge-search:'Forge - 搜索优化':npm run lint"
AGENTS["pixel"]="$WORKTREE_BASE/pixel-dark:'Pixel - 暗色主题':npm run build"
AGENTS["kernel"]="$WORKTREE_BASE/kernel-docker:'Kernel - Docker 优化':docker images"

for agent in "${!AGENTS[@]}"; do
  IFS=':' read -r workdir desc cmd <<< "${AGENTS[$agent]}"
  session="m3u-$agent"

  echo "启动: $agent -> $workdir"
  tmux -S "$SOCKET" new-session -d -s "$session" -n work

  # 发送命令
  tmux -S "$SOCKET" send-keys -t "$session":0.0 "clear" Enter
  tmux -S "$SOCKET" send-keys -t "$session":0.0 "echo '🤖 Agent: $agent'" Enter
  tmux -S "$SOCKET" send-keys -t "$session":0.0 "echo '📋 $desc'" Enter
  tmux -S "$SOCKET" send-keys -t "$session":0.0 "echo '📂 $workdir'" Enter
  tmux -S "$SOCKET" send-keys -t "$session":0.0 "echo '' && echo '🚀 开始执行...'" Enter
  sleep 0.2

  # 执行命令
  tmux -S "$SOCKET" send-keys -t "$session":0.0 "cd $workdir && $cmd" Enter
done

echo ""
echo "✅ 3 个 agents 已启动"
echo "查看: tmux -S $SOCKET list-sessions"
echo "监控: tmux -S $SOCKET attach -t m3u-forge（或 pixel/kernel）"
echo "停止: tmux -S $SOCKET kill-server"
