#!/bin/bash
set -euo pipefail

PROJECT="/home/deepnight/.openclaw/workspace/projects/m3u-player"
BASE_WORK="/home/deepnight/.openclaw/workspace/team-m3u-agents"
SOCKET="/tmp/clawdbot-tmux-sockets/team-run.sock"
MONITOR_SOCK="/tmp/clawdbot-tmux-sockets/team-monitor.sock"

rm -rf "$BASE_WORK"
mkdir -p "$BASE_WORK"
tmux -S "$SOCKET" kill-server 2>/dev/null || true
tmux -S "$MONITOR_SOCK" kill-server 2>/dev/null || true

echo "🚀 M3U Player 团队作战启动"

# 克隆
for branch in atlas-task forge-lint pixel-ui kernel-docker sentinel-qa; do
  workdir="$BASE_WORK/$branch"
  if [[ ! -d "$workdir/.git" ]]; then
    echo "克隆: $branch"
    git clone "$PROJECT" "$workdir" 2>/dev/null
    (cd "$workdir" && git checkout -b "$branch" 2>/dev/null) || true
  fi
done

send_task() {
  local win=$1
  local desc=$2
  local cmd=$3
  tmux -S "$SOCKET" send-keys -t "$win" "clear" Enter
  tmux -S "$SOCKET" send-keys -t "$win" "echo '======================================='" Enter
  tmux -S "$SOCKET" send-keys -t "$win" "echo '$desc'" Enter
  tmux -S "$SOCKET" send-keys -t "$win" "echo '======================================='" Enter
  sleep 0.2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    tmux -S "$SOCKET" send-keys -t "$win" "$line" Enter
    sleep 0.15
  done <<< "$(echo "$cmd" | tr ';' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')"
}

# 启动团队会话
tmux -S "$SOCKET" new-session -d -s team -n all-agents

# 各成员任务
send_task "team:0" "📋 Atlas (PM) 项目规划" "echo '分析需求...'; echo '任务列表: 搜索优化、暗色主题、Docker 优化'; echo '✅ 完成'"
tmux -S "$SOCKET" new-window -t team -n forge-lint
sleep 0.3
send_task "team:forge-lint" "🔧 Forge (Coder) 代码检查" "cd $BASE_WORK/forge-lint; npm run lint 2>&1 | head -30 || echo '(lint 不可用)'; wc -l app.js index.html 2>/dev/null || echo '文件未找到'"
tmux -S "$SOCKET" new-window -t team -n pixel-ui
sleep 0.3
send_task "team:pixel-ui" "🎨 Pixel (Designer) UI 分析" "cd $BASE_WORK/pixel-ui; echo '分析 UI 组件...'; grep -cE '<div|</div|<button|<input' index.html 2>/dev/null || echo 'index.html 未找到'"
tmux -S "$SOCKET" new-window -t team -n kernel-docker
sleep 0.3
send_task "team:kernel-docker" "⚙️  Kernel (DevOps) 环境检查" "echo 'Docker 容器:'; docker ps --filter name=m3u 2>/dev/null || echo 'Docker 不可用'; docker images | grep m3u 2>/dev/null || echo '无 m3u 镜像'"
tmux -S "$SOCKET" new-window -t team -n sentinel-qa
sleep 0.3
send_task "team:sentinel-qa" "🛡️ Sentinel (QA) 质量评估" "cd $BASE_WORK/sentinel-qa; echo '文件检查:'; ls -l server.js app.js index.html package.json 2>/dev/null && echo '✅ 核心文件存在' || echo '文件缺失'; echo '端口 3456:'; (netstat -tuln 2>/dev/null | grep :3456 || ss -tuln 2>/dev/null | grep :3456 || echo '未监听'); echo '数据库:'; du -h data/m3u-player.db 2>/dev/null || echo 'N/A'"

echo ""
echo "✅ agents 启动完成"
echo "详细视图: tmux -S $SOCKET attach -t team"
echo ""

# 监控视图
tmux -S "$MONITOR_SOCK" kill-server 2>/dev/null || true
tmux -S "$MONITOR_SOCK" new-session -d -s team-monitor -n overview
tmux -S "$MONITOR_SOCK" split-window -v -t team-monitor
tmux -S "$MONITOR_SOCK" split-window -v -t team-monitor:0.0
tmux -S "$MONITOR_SOCK" split-window -h -t team-monitor
tmux -S "$MONITOR_SOCK" split-window -h -t team-monitor:0.2
tmux -S "$MONITOR_SOCK" split-window -h -t team-monitor:0.4
tmux -S "$MONITOR_SOCK" select-layout tiled 2>/dev/null || true
sleep 0.3

fill_monitor() {
  local pane=$1
  local win=$2
  local title=$3
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "clear; echo -e '\\033[1;33m[$title]\\033[0m'; echo ''" Enter
  output=$(tmux -S "$SOCKET" capture-pane -p -t "team:$win" -S -20 2>/dev/null || echo "等待输出...")
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "$output" Enter
}

fill_monitor "team-monitor:0.0" "0" "🖥️  你的默认会话"
fill_monitor "team-monitor:0.1" "atlas-task" "📋 Atlas (PM)"
fill_monitor "team-monitor:0.2" "forge-lint" "🔧 Forge (Coder)"
fill_monitor "team-monitor:0.3" "pixel-ui" "🎨 Pixel (Designer)"
fill_monitor "team-monitor:0.4" "kernel-docker" "⚙️  Kernel (DevOps)"
fill_monitor "team-monitor:0.5" "sentinel-qa" "🛡️ Sentinel (QA)"

echo "✅ 团队监控就绪！"
echo "汇总视图: tmux -S $MONITOR_SOCK attach -t team-monitor"
echo "详细视图: tmux -S $SOCKET attach -t team"

cat > update-team-monitor.sh << 'EOF'
#!/bin/bash
MONITOR_SOCK="/tmp/clawdbot-tmux-sockets/team-monitor.sock"
TEAM_SOCK="/tmp/clawdbot-tmux-sockets/team-run.sock"
mappings=(
  "team-monitor:0.0:0:🖥️  你的默认会话"
  "team-monitor:0.1:atlas-task:📋 Atlas (PM)"
  "team-monitor:0.2:forge-lint:🔧 Forge (Coder)"
  "team-monitor:0.3:pixel-ui:🎨 Pixel (Designer)"
  "team-monitor:0.4:kernel-docker:⚙️  Kernel (DevOps)"
  "team-monitor:0.5:sentinel-qa:🛡️ Sentinel (QA)"
)
for line in "${mappings[@]}"; do
  IFS=':' read -r pane win title <<< "$line"
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "clear; echo -e '\\033[1;33m[$title]\\033[0m'; echo ''" Enter
  out=$(tmux -S "$TEAM_SOCK" capture-pane -p -t "team:$win" -S -20 2>/dev/null || echo "等待输出...")
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "$out" Enter
done
EOF
chmod +x update-team-monitor.sh
echo "更新脚本: $(pwd)/update-team-monitor.sh"
