#!/bin/bash
# M3U Player - 并行改进任务配置（简化版，不依赖远程仓库）

set -euo pipefail

# ==================== 配置区域 ====================
PROJECT_DIR="/home/deepnight/.openclaw/workspace/projects/m3u-player"
WORKTREE_BASE="${PROJECT_DIR}-worktrees"
SOCKET_DIR="${TMPDIR:-/tmp}/clawdbot-tmux-sockets"
SOCKET="${SOCKET_DIR}/m3u-player-agents.sock"
# ================================================

mkdir -p "$SOCKET_DIR" "$WORKTREE_BASE"

# 清理旧会话
tmux -S "$SOCKET" kill-server 2>/dev/null || true

echo "🚀 M3U Player 并行改进任务启动（本地分支模式）"
echo "项目: $PROJECT_DIR"
echo "Worktree 目录: $WORKTREE_BASE"
echo "Socket: $SOCKET"
echo ""

# 检查主仓库
if ! git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "❌ 错误: $PROJECT_DIR 不是 git 仓库"
  exit 1
fi

# 确保我们在 main 分支（或 master）
MAIN_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
echo "📍 主分支: $MAIN_BRANCH"
echo ""

# 定义任务：branch_name : 描述 : agent_name : 命令
TASKS=(
  "search-enhancement:'Forge - 搜索过滤优化':'forge':'npm run lint && npm test'"
  "dark-mode:'Pixel - 暗色主题实现':'pixel':'echo \"设计暗色配色方案...\" && sleep 2 && echo \"实现主题切换逻辑...\" && npm run build'"
  "docker-optimize:'Kernel - Docker 优化':'kernel':'docker build -t m3u-player:optimized . 2>&1 | tail -20'"
)

echo "🔧 准备工作树..."
for task_def in "${TASKS[@]}"; do
  IFS=':' read -r branch desc agent_name cmd <<< "$task_def"
  workdir="${WORKTREE_BASE}/${branch}"

  # 创建工作目录
  mkdir -p "$workdir"

  # 创建或更新 worktree（基于 main 分支创建新分支）
  # 检查 worktree 是否有效
  if [[ -f "$workdir/.git" ]] || [[ -d "$workdir/.git" ]]; then
    echo "  ↯ Worktree 已存在: $branch (更新...)"
    (cd "$workdir" && git checkout "$branch" 2>/dev/null && git pull .. "$MAIN_BRANCH" 2>/dev/null || true)
  else
    echo "  ✨ 创建 worktree: $branch"
    # 从 main 分支创建新分支
    git -C "$PROJECT_DIR" worktree add -b "$branch" "$workdir" "$MAIN_BRANCH" 2>/dev/null || {
      echo "  ⚠️  worktree 创建失败，尝试手动初始化..."
      git clone "$PROJECT_DIR" "$workdir" 2>/dev/null
      git -C "$workdir" checkout -b "$branch" 2>/dev/null
    }
  fi
done

echo ""
echo "🤖 启动并行 agents..."

for task_def in "${TASKS[@]}"; do
  IFS=':' read -r branch desc agent_name cmd <<< "$task_def"
  workdir="${WORKTREE_BASE}/${branch}"
  SESSION_NAME="m3u-${agent_name}"  # 使用 agent 名称作为会话名

  # 跳过无效的工作树
  [[ -f "$workdir/.git" ]] || [[ -d "$workdir/.git" ]] || { echo "  ⚠️  跳过 $branch (worktree 不存在)"; continue; }

  # 创建 tmux 会话
  tmux -S "$SOCKET" new-session -d -s "$SESSION_NAME" -n work

  # 欢迎信息
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "echo '================================'" Enter
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "echo '🤖 Agent: $agent_name'" Enter
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "echo '📋 任务: $desc'" Enter
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "echo '📂 工作目录: $workdir'" Enter
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "echo '🌿 分支: $branch'" Enter
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "echo '================================'" Enter
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "cd $workdir && git status --short" Enter
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "cd $workdir && pwd" Enter

  # 执行任务命令
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "cd $workdir && echo '' && echo '🚀 开始执行任务...'" Enter
  sleep 0.3
  # 拆分命令序列，每行一个命令，更稳定
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "cd $workdir && $line" Enter
    sleep 0.2
  done <<< "$(echo "$cmd" | tr ';' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')"

  echo "  ✅ $SESSION_NAME - $desc"
done

echo ""
echo "✅ 所有 agents 已启动，正在并行工作"
echo ""
echo "📊 监控命令："
echo "  查看所有会话: tmux -S $SOCKET list-sessions"
echo ""
echo "查看某个 agent 的实时输出："
for task_def in "${TASKS[@]}"; do
  IFS=':' read -r branch desc agent_name cmd <<< "$task_def"
  workdir="${WORKTREE_BASE}/${branch}"
  [[ -d "$workdir/.git" ]] || continue
  SESSION_NAME="m3u-${agent_name}"
  echo "  tmux -S $SOCKET attach -t $SESSION_NAME   # $desc"
done
echo "  # 退出监控：Ctrl+b d"
echo ""
echo "获取输出快照（不 attach）："
echo "  tmux -S $SOCKET capture-pane -p -t m3u-forge:0.0 -S -50"
echo ""
echo "检查任务完成状态（等待提示符 ❯ 或 \$）："
echo "  for sess in \$(tmux -S $SOCKET list-sessions -F '#{session_name}'); do"
echo "    if tmux -S $SOCKET capture-pane -p -t \"\$sess:0.0\" -S -3 | grep -qE '[❯\$]'; then"
echo "      echo \"\$sess: ✅ 已完成\""
echo "    else"
echo "      echo \"\$sess: 🏃 运行中\""
echo "    fi"
echo "  done"
echo ""
echo "🛑 停止所有 agents："
echo "  tmux -S $SOCKET kill-server"
echo ""
echo "💡 提示："
echo "  - 每个 agent 在独立的工作目录，互不干扰"
echo "  - 工作目录位于: $WORKTREE_BASE/{branch}"
echo "  - 任务完成后可以在 Star Office 看板上标记完成"
echo "  - 记得定期合并 main 分支的更新"
echo ""

# 显示当前会话列表
sleep 1
echo "当前运行的 tmux 会话："
tmux -S "$SOCKET" list-sessions 2>/dev/null || echo "  (无活跃会话)"
