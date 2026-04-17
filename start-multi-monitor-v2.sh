#!/bin/bash
# 多会话监控 - 修正版（使用 tiled 布局）

set -euo pipefail

MONITOR_SOCK="/tmp/clawdbot-tmux-sockets/monitor.sock"
MAIN_SOCK="/tmp/tmux-1000/default"
AGENT_SOCK="/tmp/clawdbot-tmux-sockets/m3u-agent-run.sock"

tmux -S "$MONITOR_SOCK" kill-server 2>/dev/null || true

# 创建新会话
tmux -S "$MONITOR_SOCK" new-session -d -s monitor -n all

# 创建 3 个额外 pane（总共 4 个）
tmux -S "$MONITOR_SOCK" split-window -v -t monitor
tmux -S "$MONITOR_SOCK" split-window -h -t monitor:0.0
tmux -S "$MONITOR_SOCK" split-window -h -t monitor:0.2

# 切换到 tiled 布局
tmux -S "$MONITOR_SOCK" select-layout tiled

# 休眠确保 pane 创建完成
sleep 0.2

# Pane 分配（tiled 布局索引可能不同，我们通过 select-pane 来精确控制）
# 先获取 pane 列表
mapfile -t panes < <(tmux -S "$MONITOR_SOCK" list-panes -F '#{pane_index}')
echo "Panes: ${panes[*]}"

# 我们手动指定目标 pane（通常 tiled 后 4 个 pane 索引为 0 1 2 3）
pane0="monitor:0.0"
pane1="monitor:0.1"
pane2="monitor:0.2"
pane3="monitor:0.3"

# 填充内容
fill_pane() {
  local pane=$1
  local sock=$2
  local sess=$3
  local title=$4

  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "clear" Enter
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "echo -e '\\033[1;36m=== $title ===\\033[0m'" Enter
  sleep 0.1
  output=$(tmux -S "$sock" capture-pane -p -t "$sess:0.0" -S -20 2>/dev/null || echo "Session not available")
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "$output" Enter
}

# 分配
fill_pane "$pane0" "$MAIN_SOCK" "0" "🖥️  默认会话 (你的终端)"
fill_pane "$pane1" "$AGENT_SOCK" "agent-forge" "🔧 Forge (代码检查)"
fill_pane "$pane2" "$AGENT_SOCK" "agent-kernel" "⚙️  Kernel (Docker)"
fill_pane "$pane3" "$AGENT_SOCK" "agent-pixel" "🎨 Pixel (UI 构建)"

echo ""
echo "✅ 监控布局已创建"
echo "查看: tmux -S $MONITOR_SOCK attach -t monitor"
echo "退出: Ctrl+b d"
echo ""
echo "💡 手动刷新：运行 ./update-monitor.sh"
echo ""

# 生成更新脚本
cat > update-monitor.sh << 'EOF'
#!/bin/bash
MONITOR_SOCK="/tmp/clawdbot-tmux-sockets/monitor.sock"
MAIN_SOCK="/tmp/tmux-1000/default"
AGENT_SOCK="/tmp/clawdbot-tmux-sockets/m3u-agent-run.sock"

assignments=(
  "monitor:0.0:/tmp/tmux-1000/default:0:🖥️  默认会话"
  "monitor:0.1:/tmp/clawdbot-tmux-sockets/m3u-agent-run.sock:agent-forge:🔧 Forge"
  "monitor:0.2:/tmp/clawdbot-tmux-sockets/m3u-agent-run.sock:agent-kernel:⚙️  Kernel"
  "monitor:0.3:/tmp/clawdbot-tmux-sockets/m3u-agent-run.sock:agent-pixel:🎨 Pixel"
)

for line in "${assignments[@]}"; do
  IFS=':' read -r pane sock sess title <<< "$line"
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "clear; echo -e '\\033[1;36m=== $title ===\\033[0m'" Enter
  output=$(tmux -S "$sock" capture-pane -p -t "$sess:0.0" -S -15 2>/dev/null || echo "Session unavailable")
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "$output" Enter
done
EOF

chmod +x update-monitor.sh
echo "📝 更新脚本已保存: $(pwd)/update-monitor.sh"
