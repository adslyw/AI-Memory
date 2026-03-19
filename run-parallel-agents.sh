#!/bin/bash
# 真实 coding agents 并行运行模板
# 适用于 codex, claude-code, openai 等 CLI 工具

set -euo pipefail

# 配置
SOCKET_DIR="${TMPDBOT_TMUX_SOCKET_DIR:-${TMPDIR:-/tmp}/clawdbot-tmux-sockets}"
SOCKET="${SOCKET_DIR}/agents-army.sock"
WORKDIR_BASE="/home/deepnight/.openclaw/workspace/agent-workspaces"
mkdir -p "$SOCKET_DIR" "$WORKDIR_BASE"

# 清理旧会话（可选）
# tmux -S "$SOCKET" kill-server 2>/dev/null || true

echo "🧠 启动并行 Coding Agents"
echo "Socket: $SOCKET"
echo ""

# 定义 agents 列表（可配置）
# 格式: "name:workdir:command"
AGENTS=(
  "forge:${WORKDIR_BASE}/agent-1:'codex --yolo \"优化性能瓶颈\"'"
  "pixel:${WORKDIR_BASE}/agent-2:'claude-code \"修复 UI 布局问题\"'"
  "kernel:${WORKDIR_BASE}/agent-3:'npm run lint && npm test'"
)

# 创建会话
for agent_def in "${AGENTS[@]}"; do
  IFS=':' read -r name workdir cmd <<< "$agent_def"

  # 创建工作目录
  mkdir -p "$workdir"
  # 如果需要，可以在这里克隆仓库或准备环境

  echo "🚀 启动 Agent: $name"
  tmux -S "$SOCKET" new-session -d -s "$name" -n work

  # 发送任务命令
  # 对于 Python REPL 类型任务，设置 PYTHON_BASIC_REPL=1
  if [[ "$cmd" == python* ]] || [[ "$cmd" == *"python"* ]]; then
    tmux -S "$SOCKET" send-keys -t "$name":0.0 "cd $workdir && PYTHON_BASIC_REPL=1 $cmd" Enter
  else
    tmux -S "$SOCKET" send-keys -t "$name":0.0 "cd $workdir && $cmd" Enter
  fi
done

echo ""
echo "✅ 所有 agents 已启动，正在并行执行任务"
echo ""
echo "📊 监控命令："
echo "  列出所有会话: tmux -S $SOCKET list-sessions"
echo "  查看 agent 输出: tmux -S $SOCKET attach -t <name>"
echo "  获取输出快照: tmux -S $SOCKET capture-pane -p -t <name>:0.0 -S -100"
echo "  检查是否完成: tmux -S $SOCKET capture-pane -p -t <name> -S -3 | grep -q '❯' && echo DONE"
echo ""
echo "🛑 停止 agents："
echo "  停止单个: tmux -S $SOCKET kill-session -t <name>"
echo "  停止全部: tmux -S $SOCKET kill-server"
echo ""

# 实际使用建议
echo "💡 使用建议："
echo "  - 每个 agent 使用独立工作目录，避免冲突"
echo "  - 使用 git worktrees 可以让 agents 在不同分支并行工作"
echo "  - 通过 prompt (❯ 或 \$) 判断任务是否完成"
echo "  - 需要交互？可以 attach 到对应会话人工介入"
echo ""
