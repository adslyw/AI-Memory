#!/bin/bash
# M3U Player - 并行改进任务配置
# 让 Forge、Pixel、Kernel 同时处理不同功能

set -euo pipefail

# ==================== 配置区域 ====================
# 使用整个 workspace 作为 git 仓库
REPO_DIR="/home/deepnight/.openclaw/workspace"
PROJECT_SUBDIR="projects/m3u-player"  # 项目在仓库中的相对路径
PROJECT_DIR="${REPO_DIR}/${PROJECT_SUBDIR}"
WORKTREE_BASE="${REPO_DIR}/m3u-player-worktrees"
SOCKET_DIR="${TMPDIR:-/tmp}/clawdbot-tmux-sockets"
SOCKET="${SOCKET_DIR}/m3u-player-agents.sock"
# ================================================

mkdir -p "$SOCKET_DIR" "$WORKTREE_BASE"

# 清理旧会话
tmux -S "$SOCKET" kill-server 2>/dev/null || true

echo "🚀 M3U Player 并行改进任务启动"
echo "项目: $PROJECT_DIR"
echo "Worktree 目录: $WORKTREE_BASE"
echo "Socket: $SOCKET"
echo ""

# 检查主仓库
if [[ ! -d "$PROJECT_DIR/.git" ]] && ! git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "❌ 错误: $PROJECT_DIR 不是 git 仓库"
  echo "请先初始化: cd $PROJECT_DIR && git init"
  exit 1
fi

# 确保主仓库有所有远程分支（如果配置了 origin）
echo "📥 检查远程仓库..."
if git -C "$PROJECT_DIR" remote get-url origin >/dev/null 2>&1; then
  (cd "$PROJECT_DIR" && git fetch origin --quiet) || echo "⚠️  Fetch 失败，继续使用本地分支"
else
  echo "ℹ️  无远程仓库，使用本地分支"
fi

# 定义任务：branch_name : 描述 : 工作目录 : 命令
TASKS=(
  "feature/search-enhancement:'Forge - 搜索过滤优化':'${WORKTREE_BASE}/search-enhancement':'npm run lint && npm test'"
  "feature/dark-mode:'Pixel - 暗色主题实现':'${WORKTREE_BASE}/dark-mode':'echo \"设计暗色配色...\" && sleep 2 && echo \"实现主题切换...\" && npm run build'"
  "enhancement/docker-optimize:'Kernel - Docker 优化':'${WORKTREE_BASE}/docker-optimize':'docker build -t m3u-player:optimized . && docker images | grep m3u-player'"
)

echo "🔧 准备工作树 (git worktrees)..."
for task_def in "${TASKS[@]}"; do
  IFS=':' read -r branch desc workdir cmd <<< "$task_def"

  # 创建工作目录
  mkdir -p "$workdir"

  # 检查分支是否存在（本地或远程）
  if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$branch" || \
     git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    # 分支存在，创建或更新 worktree
    if [[ -d "$workdir/.git" ]]; then
      echo "  ↯ 更新 worktree: $branch"
      (cd "$workdir" && git checkout "$branch" && git pull origin "$branch" 2>/dev/null || true)
    else
      echo "  ✨ 创建 worktree: $branch"
      git -C "$PROJECT_DIR" worktree add "$workdir" "$branch" 2>/dev/null || \
      git -C "$PROJECT_DIR" worktree add -b "$branch" "$workdir" "origin/$branch" 2>/dev/null || \
      echo "  ⚠️  跳过 $branch (无法创建)"
    fi
  else
    echo "  ⚠️  分支不存在: $branch (跳过)"
    continue
  fi
done

echo ""
echo "🤖 启动并行 agents..."

for task_def in "${TASKS[@]}"; do
  IFS=':' read -r branch desc workdir cmd <<< "$task_def"

  # 跳过不存在的工作树
  [[ -d "$workdir/.git" ]] || continue

  SESSION_NAME="m3u-${branch//\//-}"  # 替换 / 为 -

  # 创建 tmux 会话
  tmux -S "$SOCKET" new-session -d -s "$SESSION_NAME" -n work

  # 欢迎信息
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "echo '================================'" Enter
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "echo '📋 任务: $desc'" Enter
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "echo '📂 工作目录: $workdir'" Enter
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "echo '🌿 分支: $branch'" Enter
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "echo '================================'" Enter
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "cd $workdir && pwd" Enter

  # 执行任务命令
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "cd $workdir && echo '🚀 开始执行任务...'" Enter
  sleep 0.3
  tmux -S "$SOCKET" send-keys -t "$SESSION_NAME":0.0 "cd $workdir && $cmd" Enter

  echo "  ✅ $SESSION_NAME - $desc"
done

echo ""
echo "✅ 所有 agents 已启动，正在并行工作"
echo ""
echo "📊 监控命令："
echo "  查看所有会话: tmux -S $SOCKET list-sessions"
echo ""
echo "查看某个 agent 的实时输出："
echo "  tmux -S $SOCKET attach -t m3u-feature-search-enhancement"
echo "  tmux -S $SOCKET attach -t m3u-feature-dark-mode"
echo "  tmux -S $SOCKET attach -t m3u-enhancement-docker-optimize"
echo "  # 退出监控：Ctrl+b d"
echo ""
echo "获取输出快照（不 attach）："
echo "  tmux -S $SOCKET capture-pane -p -t m3u-feature-search-enhancement:0.0 -S -50"
echo ""
echo "检查任务完成状态（等待提示符 ❯ 或 $）："
echo "  for sess in \$(tmux -S $SOCKET list-sessions -F '#{session_name}'); do"
echo "    if tmux -S $SOCKET capture-pane -p -t \"\$sess:0.0\" -S -3 | grep -q '❯'; then"
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
echo "  - 任务完成后可以在 Star Office 看板上标记完成"
echo "  - 记得定期 pull 主仓库同步最新代码"
echo ""

# 显示当前会话列表
sleep 1
echo "当前运行的 tmux 会话："
tmux -S "$SOCKET" list-sessions 2>/dev/null || echo "  (无活跃会话)"
