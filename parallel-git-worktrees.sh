#!/bin/bash
# 使用 git worktrees 并行处理不同分支的实战示例
# 假设你要让多个 agents 同时处理不同功能分支

set -euo pipefail

SOCKET_DIR="${TMPDIR:-/tmp}/clawdbot-tmux-sockets"
SOCKET="${SOCKET_DIR}/git-worktree-agents.sock"
MAIN_REPO="/home/deepnight/projects/m3u-player"  # 修改为你的项目路径
WORKTREE_BASE="${MAIN_REPO}-worktrees"
mkdir -p "$SOCKET_DIR" "$WORKTREE_BASE"

# 清理旧会话
tmux -S "$SOCKET" kill-server 2>/dev/null || true

echo "🌿 Git Worktrees + tmux 并行 agents"
echo "主仓库: $MAIN_REPO"
echo "Worktree 目录: $WORKTREE_BASE"
echo ""

# 检查主仓库
if [[ ! -d "$MAIN_REPO/.git" ]]; then
  echo "❌ 主仓库不存在或不是 git 仓库: $MAIN_REPO"
  exit 1
fi

# 定义并行任务（branch : task description : agent command）
TASKS=(
  "feature/hls-optimization:'HLS 流优化':'npm run lint && npm test'"
  "bugfix/playlist-crash:'播放列表崩溃修复':'node tests/playlist-stress.js'"
  "enhancement/dark-mode:'暗色主题实现':'echo \"实现暗色主题...\" && sleep 5'"
)

echo "🔧 准备 worktrees..."
for task_def in "${TASKS[@]}"; do
  IFS=':' read -r branch desc cmd <<< "$task_def"

  WT_DIR="${WORKTREE_BASE}/${branch//\//-}"  # 替换 / 为 - 避免路径问题
  BRANCH_NAME="$branch"

  # 如果 worktree 已存在，更新；否则创建
  if [[ -d "$WT_DIR/.git" ]]; then
    echo "  ↯ 更新 worktree: $branch → $WT_DIR"
    (cd "$WT_DIR" && git pull origin "$branch" 2>/dev/null || true)
  else
    echo "  ✨ 创建 worktree: $branch → $WT_DIR"
    git worktree add -b "$branch" "$WT_DIR" "origin/$branch" 2>/dev/null || \
    git worktree add "$WT_DIR" "$branch" 2>/dev/null || \
    echo "  ⚠️  跳过 $branch (分支不存在?)"
  fi
done

echo ""
echo "🤖 启动 agents..."
SESSION_PIDS=()

for task_def in "${TASKS[@]}"; do
  IFS=':' read -r branch desc cmd <<< "$task_def"
  WT_DIR="${WORKTREE_BASE}/${branch//\//-}"

  # 跳过不存在的 worktree
  [[ -d "$WT_DIR" ]] || continue

  SESSION_NAME="agent-${branch//\//-}"

  # 创建 tmux 会话
  tmux -S "$SOCKET" new-session -d -s "$SESSION_NAME" -n work

  # 发送命令（设置工作目录 + 执行任务）
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "cd $WT_DIR && echo \"[${desc}] 开始工作...\"" Enter
  sleep 0.2
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "cd $WT_DIR && $cmd" Enter

  echo "  ✅ $SESSION_NAME (${desc})"
done

echo ""
echo "📈 所有 agents 已启动，正在不同分支并行工作"
echo ""
echo "实时监控："
echo "  查看会话列表: tmux -S $SOCKET list-sessions"
echo ""
echo "检查某个 agent 的输出："
echo "  tmux -S $SOCKET attach -t agent-feature-hls-optimization"
echo "  # 退出监控: Ctrl+b d"
echo ""
echo "获取输出快照（不需要 attach）："
echo "  tmux -S $SOCKET capture-pane -p -t agent-feature-hls-optimization:0.0 -S -50"
echo ""
echo "清理 worktrees 和 tmux 会话："
echo "  # 停止 agents"
echo "  tmux -S $SOCKET kill-server"
echo "  # 删除 worktrees"
echo "  git worktree list | awk '{print \$1}' | grep '$WORKTREE_BASE' | xargs -r git worktree remove"
echo ""

# 演示用途：等待任务完成
echo "⏳ 等待 agents 完成（这里只是演示，实际会一直运行）..."
echo "你可以打开新终端运行上面的监控命令"
echo ""
echo "完成后记得清理："
echo "  tmux -S $SOCKET kill-server"
echo ""
