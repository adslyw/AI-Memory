#!/bin/bash
# 团队作战监控 - 所有 5 个 agents + 默认会话（修复版）

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

# Team members with their tasks（使用绝对路径避免变量问题）
TEAM_TASKS=(
  "atlas-task:'📋 Atlas (PM) 项目规划':'echo \"分析需求...\" && echo \"任务列表: 搜索优化、暗色主题、Docker 优化\" && echo \"✅ 分配完成\"'"

  "forge-lint:'🔧 Forge (Coder) 代码检查':'cd /home/deepnight/.openclaw/workspace/team-m3u-agents/forge-lint && npm run lint 2>&1 | head -30 || echo \"(lint 不可用) 检查文件大小:\" && wc -l app.js index.html 2>/dev/null || echo \"文件未找到\"'"

  "pixel-ui:'🎨 Pixel (Designer) UI 分析':'cd /home/deepnight/.openclaw/workspace/team-m3u-agents/pixel-ui && echo \"分析 UI 组件...\" && grep -c '<div\\|</div\\|<button\\|<input' index.html 2>/dev/null || echo \"index.html 未找到\"'"

  "kernel-docker:'⚙️  Kernel (DevOps) 环境检查':'docker ps --filter name=m3u && docker images | grep m3u && echo \"容器与镜像状态正常\" || echo \"Docker 服务异常\"'"

  "sentinel-qa:'🛡️ Sentinel (QA) 质量评估':'cd /home/deepnight/.openclaw/workspace/team-m3u-agents/sentinel-qa && echo \"文件检查:\" && ls -l server.js app.js index.html package.json 2>/dev/null && echo \"端口 3456:\" && (netstat -tuln 2>/dev/null | grep :3456 || ss -tuln 2>/dev/null | grep :3456 || echo \"未监听\") && echo \"数据库:\" && du -h data/m3u-player.db 2>/dev/null || echo \"N/A\"'"
)

# 1. 准备工作副本
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

# 2. 启动 tmux sessions
echo ""
echo "🤖 启动团队 agents..."

tmux -S "$SOCKET" new-session -d -s team -n all-agents

window_index=0
for task in "${TEAM_TASKS[@]}"; do
  IFS=':' read -r branch desc cmd <<< "$task"
  workdir="$BASE_WORK/$branch"

  if [[ $window_index -eq 0 ]]; then
    window="team:0"
  else
    tmux -S "$SOCKET" new-window -t team -n "$branch"
    window="team:$window_index"
  fi

  tmux -S "$SOCKET" send-keys -t "$window" "clear" Enter
  tmux -S "$SOCKET" send-keys -t "$window" "echo '======================================='" Enter
  tmux -S "$SOCKET" send-keys -t "$window" "echo '$desc'" Enter
  tmux -S "$SOCKET" send-keys -t "$window" "echo 'Workdir: $workdir'" Enter
  tmux -S "$SOCKET" send-keys -t "$window" "echo '======================================='" Enter
  sleep 0.2
  tmux -S "$SOCKET" send-keys -t "$window" "$cmd" Enter

  echo "  ✅ $branch"
  window_index=$((window_index + 1))
done

echo ""
echo "✅ 所有 team agents 已启动"
echo ""
echo "📊 监控命令："
echo "  查看所有 windows: tmux -S $SOCKET list-windows -t team"
echo "  查看输出: tmux -S $SOCKET attach -t team"
echo "  切换 window: Ctrl+b then 0-4"
echo "  停止全部: tmux -S $SOCKET kill-session -t team"
echo ""
echo "💡 工作目录:"
for task in "${TEAM_TASKS[@]}"; do
  IFS=':' read -r branch desc cmd <<< "$task"
  echo "  $branch: $BASE_WORK/$branch"
done
echo ""

# 3. 创建多会话监控视图
echo "🖥️ 创建团队监控汇总视图..."
tmux -S "$MONITOR_SOCK" kill-server 2>/dev/null || true
tmux -S "$MONITOR_SOCK" new-session -d -s team-monitor -n overview

# 6 个 pane (3x2)
tmux -S "$MONITOR_SOCK" split-window -v -t team-monitor
tmux -S "$MONITOR_SOCK" split-window -v -t team-monitor:0.0
tmux -S "$MONITOR_SOCK" split-window -h -t team-monitor
tmux -S "$MONITOR_SOCK" split-window -h -t team-monitor:0.2
tmux -S "$MONITOR_SOCK" split-window -h -t team-monitor:0.4
tmux -S "$MONITOR_SOCK" select-layout tiled 2>/dev/null || true

sleep 0.3

# 填充汇总内容
MAIN_SOCK="/tmp/tmux-1000/default"
TEAM_SOCK="$SOCKET"

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
  output=$(tmux -S "$TEAM_SOCK" capture-pane -p -t "team:$branch" -S -15 2>/dev/null || echo "等待输出...")
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "$output" Enter
done

echo "✅ 团队监控就绪！"
echo ""
echo "🚀 查看方式："
echo "  汇总视图: tmux -S $MONITOR_SOCK attach -t team-monitor"
echo "  详细视图: tmux -S $SOCKET attach -t team"
echo "  刷新汇总: ./update-team-monitor.sh"
echo ""
echo "📝 更新脚本已生成: $(pwd)/update-team-monitor.sh"

# 生成更新脚本
cat > update-team-monitor.sh << 'EOF'
#!/bin/bash
MONITOR_SOCK="/tmp/clawdbot-tmux-sockets/team-monitor.sock"
TEAM_SOCK="/tmp/clawdbot-tmux-sockets/team-run.sock"
MAIN_SOCK="/tmp/tmux-1000/default"

tmux -S "$MONITOR_SOCK" send-keys -t "team-monitor:0.0" "clear; echo '🖥️  你的默认会话'" Enter
tmux -S "$MONITOR_SOCK" send-keys -t "team-monitor:0.0" "tmux -S $MAIN_SOCK capture-pane -p -t 0 -S -10 2>/dev/null || echo '无输出'" Enter

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
echo "✅ 完成！"
