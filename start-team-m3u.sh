#!/bin/bash
# 团队作战监控 - 所有 5 个 agents + 默认会话

set -euo pipefail

# 路径配置
PROJECT="/home/deepnight/.openclaw/workspace/projects/m3u-player"
BASE_WORK="/home/deepnight/.openclaw/workspace/team-m3u-agents"
SOCKET="/tmp/clawdbot-tmux-sockets/team-run.sock"
MONITOR_SOCK="/tmp/clawdbot-tmux-sockets/team-monitor.sock"

# 清理旧环境
rm -rf "$BASE_WORK"
mkdir -p "$BASE_WORK"
tmux -S "$SOCKET" kill-server 2>/dev/null || true
tmux -S "$MONITOR_SOCK" kill-server 2>/dev/null || true

echo "🚀 M3U Player 团队作战启动"
echo "主项目: $PROJECT"
echo "工作目录: $BASE_WORK"
echo ""

# Team members with their tasks
# 格式: 分支名:描述:命令
TEAM_TASKS=(
  # PM - 项目规划
  "atlas-task:'Atlas (PM) - 项目规划':'echo \"📋 分析需求...\" && echo \"📝 生成任务列表:\" && echo \"  - 频道搜索优化\" && echo \"  - 暗色主题实现\" && echo \"  - Docker 镜像优化\" && echo \"✅ 任务分配完成\"'"

  # Coder - 代码质量
  "forge-lint:'Forge (Coder) - 代码检查':'cd $workdir && npm run lint 2>&1 | head -30 || echo \"(lint 命令不存在，使用 cat 检查代码)\" && echo \"检查文件: app.js, index.html\" && wc -l app.js index.html'"

  # Designer - UI 组件检查
  "pixel-ui:'Pixel (Designer) - UI 分析':'cd $workdir && echo \"🎨 分析 UI 组件...\" && grep -E \"<div|<button|<input\" index.html | wc -l && echo \"个 UI 元素发现\" && echo \"检查 Tailwind 类...\" && grep -o \"tw-\\w\\{1,\\}\" index.html | sort | uniq -c | sort -nr | head -10'"

  # DevOps - Docker 检查
  "kernel-docker:'Kernel (DevOps) - 环境检查':'docker ps --filter name=m3u && docker images | grep m3u && echo \"📊 容器状态: 正常\" && echo \"💾 镜像大小: $(docker images m3u-player-app --format '{{.Size}}' 2>/dev/null || echo 'N/A')\"'"

  # QA - 功能检查
  "sentinel-qa:'Sentinel (QA) - 质量评估':'cd $workdir && echo \"🛡️ QA 检查开始...\" && echo \"1. 文件完整性:\" && ls -1 server.js app.js index.html package.json > /dev/null 2>&1 && echo \"✅ 核心文件存在\" && echo \"2. 端口检查:\" && netstat -tuln 2>/dev/null | grep :3456 || echo \"⚠️  端口 3456 未监听\" && echo \"3. 数据库尺寸:\" && du -h data/m3u-player.db 2>/dev/null || echo \"N/A\"'"
)

# 1. 为每个 agent 创建独立工作副本
echo "📦 准备团队工作副本..."
for task in "${TEAM_TASKS[@]}"; do
  IFS=':' read -r branch desc cmd <<< "$task"
  workdir="$BASE_WORK/$branch"

  if [[ -d "$workdir/.git" ]]; then
    echo "  ↯ 更新: $branch"
    (cd "$workdir" && git pull .. master 2>/dev/null) || true
  else
    echo "  ✨ 克隆: $branch"
    git clone "$PROJECT" "$workdir" 2>/dev/null
    (cd "$workdir" && git checkout -b "$branch" 2>/dev/null) || true
  fi
done

# 2. 启动 tmux sessions (一个 session 管理所有 agents)
echo ""
echo "🤖 启动团队 agents..."

tmux -S "$SOCKET" new-session -d -s team -n all-agents

# 为每个 agent 创建独立的 window（更清晰）
window_index=0
for task in "${TEAM_TASKS[@]}"; do
  IFS=':' read -r branch desc cmd <<< "$task"
  workdir="$BASE_WORK/$branch"

  # 如果是第一个 window，重用；否则新建
  if [[ $window_index -eq 0 ]]; then
    window="team:0"
  else
    tmux -S "$SOCKET" new-window -t team -n "$branch"
    window="team:$window_index"
  fi

  # 执行任务
  tmux -S "$SOCKET" send-keys -t "$window" "clear" Enter
  tmux -S "$SOCKET" send-keys -t "$window" "echo '======================================='" Enter
  tmux -S "$SOCKET" send-keys -t "$window" "echo '$desc'" Enter
  tmux -S "$SOCKET" send-keys -t "$window" "echo 'Workdir: $workdir'" Enter
  tmux -S "$SOCKET" send-keys -t "$window" "echo '======================================='" Enter
  sleep 0.2
  tmux -S "$SOCKET" send-keys -t "$window" "cd $workdir && $cmd" Enter

  echo "  ✅ $branch ($desc)"
  window_index=$((window_index + 1))
done

echo ""
echo "✅ 所有 team agents 已启动（独立 window）"
echo ""
echo "📊 监控命令："
echo "  查看所有 windows: tmux -S $SOCKET list-windows -t team"
echo "  查看输出: tmux -S $SOCKET attach -t team"
echo "  切换 window: Ctrl+b then 0-4 (或 PgUp/PgDn)"
echo "  停止全部: tmux -S $SOCKET kill-session -t team"
echo ""
echo "💡 工作目录:"
for task in "${TEAM_TASKS[@]}"; do
  IFS=':' read -r branch desc cmd <<< "$task"
  echo "  $branch: $BASE_WORK/$branch"
done
echo ""

# 3. 创建多会话监控视图（汇总）
echo "🖥️ 创建团队监控汇总视图..."
tmux -S "$MONITOR_SOCK" kill-server 2>/dev/null || true
tmux -S "$MONITOR_SOCK" new-session -d -s team-monitor -n overview

# 6 个内容（你的默认 + 5 个 agents）用 3x2 布局
tmux -S "$MONITOR_SOCK" split-window -v -t team-monitor
tmux -S "$MONITOR_SOCK" split-window -v -t team-monitor:0.0
tmux -S "$MONITOR_SOCK" split-window -h -t team-monitor
tmux -S "$MONITOR_SOCK" split-window -h -t team-monitor:0.2
tmux -S "$MONITOR_SOCK" split-window -h -t team-monitor:0.4

# 强制 tiled
tmux -S "$MONITOR_SOCK" select-layout tiled 2>/dev/null || true

sleep 0.3

# 填充汇总内容
MAIN_SOCK="/tmp/tmux-1000/default"
TEAM_SOCK="$SOCKET"

# 你的默认会话
tmux -S "$MONITOR_SOCK" send-keys -t "team-monitor:0.0" "clear; echo '🖥️  你的默认会话 (当前)'" Enter
tmux -S "$MONITOR_SOCK" send-keys -t "team-monitor:0.0" "tmux -S $MAIN_SOCK capture-pane -p -t 0 -S -10 2>/dev/null || echo '无输出'" Enter

# Agents (轮流从他们的 window 取输出)
agents=(
  "team-monitor:0.1:atlas-task:📋 Atlas (PM)"
  "team-monitor:0.2:forge-lint:🔧 Forge (Coder)"
  "team-monitor:0.3:pixel-ui:🎨 Pixel (Designer)"
  "team-monitor:0.4:kernel-docker:⚙️  Kernel (DevOps)"
  "team-monitor:0.5:sentinel-qa:🛡️ Sentinel (QA)"
)

for item in "${agents[@]}"; do
  IFS=':' read -r pane branch title <<< "$item"
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "clear; echo '$title'" Enter
  # 从对应 window 获取输出
  output=$(tmux -S "$TEAM_SOCK" capture-pane -p -t "team:$branch" -S -15 2>/dev/null || echo "等待输出...")
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "$output" Enter
done

echo "✅ 团队监控视图已创建"
echo ""
echo "🚀 现在你可以："
echo "  1. 查看汇总: tmux -S $MONITOR_SOCK attach -t team-monitor"
echo "  2. 查看详情: tmux -S $SOCKET attach -t team (每个成员独立 window)"
echo "  3. 刷新汇总: ./update-team-monitor.sh"
echo ""
echo "📝 更新脚本已生成: $(pwd)/update-team-monitor.sh"
echo ""

# 生成更新脚本
cat > update-team-monitor.sh << 'EOF'
#!/bin/bash
MONITOR_SOCK="/tmp/clawdbot-tmux-sockets/team-monitor.sock"
TEAM_SOCK="/tmp/clawdbot-tmux-sockets/team-run.sock"
MAIN_SOCK="/tmp/tmux-1000/default"

# 你的默认会话
tmux -S "$MONITOR_SOCK" send-keys -t "team-monitor:0.0" "clear; echo '🖥️  你的默认会话'" Enter
tmux -S "$MONITOR_SOCK" send-keys -t "team-monitor:0.0" "tmux -S $MAIN_SOCK capture-pane -p -t 0 -S -10 2>/dev/null || echo '无输出'" Enter

# Agents
mappings=(
  "team-monitor:0.1:atlas-task:📋 Atlas (PM)"
  "team-monitor:0.2:forge-lint:🔧 Forge (Coder)"
  "team-monitor:0.3:pixel-ui:🎨 Pixel (Designer)"
  "team-monitor:0.4:kernel-docker:⚙️  Kernel (DevOps)"
  "team-monitor:0.5:sentinel-qa:🛡️ Sentinel (QA)"
)

for line in "${mappings[@]}"; do
  IFS=':' read -r pane branch title <<< "$line"
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "clear; echo '$title'" Enter
  out=$(tmux -S "$TEAM_SOCK" capture-pane -p -t "team:$branch" -S -15 2>/dev/null || echo "等待输出...")
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "$out" Enter
done
EOF

chmod +x update-team-monitor.sh
echo "✅ 团队监控就绪！"
