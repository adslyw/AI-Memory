#!/bin/bash
# 多会话实时监控 - 在一个终端显示所有活跃会话

set -euo pipefail

# Socket 配置
MAIN_SOCK="/tmp/tmux-1000/default"  # 你的默认 tmux socket
AGENT_SOCK="/tmp/clawdbot-tmux-sockets/m3u-agent-run.sock"

# 监控的会话列表
SESSIONS=(
  "默认会话:0"
  "Forge:agent-forge"
  "Kernel:agent-kernel"
  "Pixel:agent-pixel"
)

# 检查
tmux -S "$MAIN_SOCK" list-sessions >/dev/null 2>&1 || MAIN_SOCK=""
tmux -S "$AGENT_SOCK" list-sessions >/dev/null 2>&1 || AGENT_SOCK=""

if [[ -z "$MAIN_SOCK" && -z "$AGENT_SOCK" ]]; then
  echo "❌ 未找到任何活跃 tmux 会话"
  exit 1
fi

echo "📊 多会话监控启动"
echo "按 Ctrl+C 退出"
echo ""

# 创建监控会话
MONITOR_SOCK="/tmp/clawdbot-tmux-sockets/monitor.sock"
tmux -S "$MONITOR_SOCK" kill-server 2>/dev/null || true
tmux -S "$MONITOR_SOCK" new-session -d -s monitor -n layout

# 清空并设置布局
tmux -S "$MONITOR_SOCK" send-keys -t monitor "clear" Enter
sleep 0.2

# 分割为 2x2 网格（4个 pane）
tmux -S "$MONITOR_SOCK" split-window -h -t monitor 50%
tmux -S "$MONITOR_SOCK" split-window -v -t monitor:0.0
tmux -S "$MONITOR_SOCK" split-window -v -t monitor:0.1

# 现在有 4 个 pane: 0.0, 0.1, 0.2, 0.3
# 分别为每个 pane 分配一个会话的输出

assign_pane() {
  local pane=$1
  local sock=$2
  local sess=$3
  local title=$4

  # 设置标题
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "echo '=== $title ==='" Enter
  sleep 0.1

  # 持续输出该会话的最新内容（通过 capture-pane 轮询）
  # 这里只做一次初始显示，后续靠 watch 脚本刷新
  output=$(tmux -S "$sock" capture-pane -p -t "$sess:0.0" -S -10 2>/dev/null || echo "会话不存在或无输出")
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "$output" Enter
}

# 分配 pane
pane_index=0
for item in "${SESSIONS[@]}"; do
  IFS=':' read -r desc sess_name <<< "$item"
  pane="monitor:0.$pane_index"

  # 决定使用哪个 socket
  if [[ "$sess_name" == "0" ]]; then
    [[ -n "$MAIN_SOCK" ]] || { echo "跳过: 默认会话未找到"; continue; }
    assign_pane "$pane" "$MAIN_SOCK" "0" "$desc"
  else
    [[ -n "$AGENT_SOCK" ]] || { echo "跳过: $desc 未找到"; continue; }
    assign_pane "$pane" "$AGENT_SOCK" "$sess_name" "$desc"
  fi

  pane_index=$((pane_index + 1))
done

echo ""
echo "监控会话已创建！"
echo "查看: tmux -S $MONITOR_SOCK attach -t monitor"
echo "退出监控: Ctrl+b d"
echo ""
echo "💡 提示：要实时刷新，请在监控会话中按 Ctrl+b : 输入 'run-shell \"$(pwd)/update-monitor.sh\"'"
echo "   或手动运行: ./update-monitor.sh"
echo ""

# 创建更新脚本
cat > update-monitor.sh << 'UPDATER'
#!/bin/bash
# 更新监控视图（从各会话拉取最新输出）
MONITOR_SOCK="/tmp/clawdbot-tmux-sockets/monitor.sock"

SESSIONS=(
  "默认会话:0"
  "Forge:agent-forge"
  "Kernel:agent-kernel"
  "Pixel:agent-pixel"
)

MAIN_SOCK="/tmp/tmux-1000/default"
AGENT_SOCK="/tmp/clawdbot-tmux-sockets/m3u-agent-run.sock"

pane_index=0
for item in "${SESSIONS[@]}"; do
  IFS=':' read -r desc sess_name <<< "$item"
  pane="monitor:0.$pane_index"

  # 清空 pane
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "clear" Enter
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "echo '=== $desc ==='" Enter

  if [[ "$sess_name" == "0" ]]; then
    output=$(tmux -S "$MAIN_SOCK" capture-pane -p -t "0" -S -15 2>/dev/null || echo "会话不可用")
  else
    output=$(tmux -S "$AGENT_SOCK" capture-pane -p -t "$sess_name:0.0" -S -15 2>/dev/null || echo "会话不可用")
  fi

  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "$output" Enter
  pane_index=$((pane_index + 1))
done
UPDATER

chmod +x update-monitor.sh
echo "✅ 更新脚本已生成: $(pwd)/update-monitor.sh"
echo ""

# 提示如何开始
echo "现在运行:"
echo "  tmux -S $MONITOR_SOCK attach -t monitor"
