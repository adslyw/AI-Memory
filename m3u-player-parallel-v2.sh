#!/bin/bash
# M3U Player - 并行改进任务配置（稳定版）

set -euo pipefail

PROJECT_DIR="/home/deepnight/.openclaw/workspace/projects/m3u-player"
WORKTREE_BASE="/home/deepnight/.openclaw/workspace/projects/m3u-player-worktrees"
SOCKET_DIR="${TMPDIR:-/tmp}/clawdbot-tmux-sockets"
SOCKET="${SOCKET_DIR}/m3u-player-agents.sock"

mkdir -p "$SOCKET_DIR"
tmux -S "$SOCKET" kill-server 2>/dev/null || true

echo "🚀 M3U Player 并行改进任务启动"
echo "项目: $PROJECT_DIR"
echo "Worktree: $WORKTREE_BASE"
echo ""

# 验证仓库
git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null || {
  echo "❌ 不是 git 仓库"
  exit 1
}

MAIN_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
echo "📍 主分支: $MAIN_BRANCH"
echo ""

# 任务定义：本地分支名 : 描述 : agent名 : 命令
TASKS=(
  "forge-search:'Forge - 搜索优化':'forge':npm run lint && npm test"
  "pixel-dark:'Pixel - 暗色主题':'pixel':echo \"配色方案: #1a1a1a 背景...\" && sleep 1 && echo \"CSS 变量定义...\" && npm run build"
  "kernel-docker:'Kernel - Docker 优化':'kernel':echo \"多阶段构建优化...\" && docker build -t m3u-player:test . && docker images | grep m3u"
)

echo "🔧 创建工作树..."
for task in "${TASKS[@]}"; do
  IFS=':' read -r branch desc agent cmd <<< "$task"
  workdir="$WORKTREE_BASE/$branch"

  # 1. 确保分支存在
  if ! git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$branch"; then
    echo "  🌿 创建分支: $branch (基于 $MAIN_BRANCH)"
    git -C "$PROJECT_DIR" branch "$branch" "$MAIN_BRANCH" 2>/dev/null || {
      # 如果分支已存在（可能在远程），尝试检出
      git -C "$PROJECT_DIR" checkout "$branch" 2>/dev/null || true
    }
  fi

  # 2. 创建工作树目录
  if [[ -d "$workdir" ]]; then
    echo "  ♻️  更新工作树: $branch"
    (cd "$workdir" && git checkout "$branch" && git pull "$PROJECT_DIR" "$branch" 2>/dev/null) || true
  else
    echo "  ✨ 新建工作树: $branch → $workdir"
    git -C "$PROJECT_DIR" worktree add -b "$branch" "$workdir" "$branch" 2>/dev/null || {
      echo "  ⚠️  worktree 失败，使用 git clone..."
      git clone "$PROJECT_DIR" "$workdir" 2>/dev/null
      git -C "$workdir" checkout "$branch" 2>/dev/null
    }
  fi
done

echo ""
echo "🤖 启动 agents..."

for task in "${TASKS[@]}"; do
  IFS=':' read -r branch desc agent cmd <<< "$task"
  workdir="$WORKTREE_BASE/$branch"
  session="m3u-$agent"

  # 验证工作树
  [[ -d "$workdir/.git" || -f "$workdir/.git" ]] || {
    echo "  ⚠️  跳过 $agent (工作树无效)"
    continue
  }

  # 创建 tmux 会话
  tmux -S "$SOCKET" new-session -d -s "$session" -n work

  # 显示任务信息
  tmux -S "$SOCKET" send-keys -t "$session":0.0 "echo '================================'" Enter
  tmux -S "$SOCKET" send-keys -t "$session":0.0 "echo '🤖 Agent: $agent'" Enter
  tmux -S "$SOCKET" send-keys -t "$session":0.0 "echo '📋 $desc'" Enter
  tmux -S "$SOCKET" send-keys -t "$session":0.0 "echo '🌿 $branch'" Enter
  tmux -S "$SOCKET" send-keys -t "$session":0.0 "echo '================================'" Enter
  tmux -S "$SOCKET" send-keys -t "$session":0.0 "cd $workdir && git status --short" Enter

  # 执行命令（支持多条命令用 ; 分隔）
  tmux -S "$SOCKET" send-keys -t "$session":0.0 "cd $workdir && echo '' && echo '🚀 开始...'" Enter
  sleep 0.2
  # 移除可能存在的引号，分割命令
  cmd_clean=$(echo "$cmd" | sed "s/^'//;s/'\$//;s/^\"//;s/\"\$//")
  IFS=';' read -ra CMD_ARR <<< "$cmd_clean"
  for c in "${CMD_ARR[@]}"; do
    c_trimmed=$(echo "$c" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [[ -n "$c_trimmed" ]] || continue
    tmux -S "$SOCKET" send-keys -t "$session":0.0 "cd $workdir && $c_trimmed" Enter
    sleep 0.3
  done

  echo "  ✅ $session - $desc"
done

echo ""
echo "✅ 所有 agents 已启动"
echo ""
echo "📊 监控："
echo "  列表: tmux -S $SOCKET list-sessions"
echo ""
echo "查看输出："
echo "  tmux -S $SOCKET attach -t m3u-forge"
echo "  tmux -S $SOCKET attach -t m3u-pixel"
echo "  tmux -S $SOCKET attach -t m3u-kernel"
echo "  退出: Ctrl+b d"
echo ""
echo "快照："
echo "  tmux -S $SOCKET capture-pane -p -t m3u-forge:0.0 -S -50"
echo ""
echo "停止："
echo "  tmux -S $SOCKET kill-server"
echo ""
echo "💡 工作目录: $WORKTREE_BASE/{branch}"
echo ""

tmux -S "$SOCKET" list-sessions 2>/dev/null || echo "无活跃会话"
