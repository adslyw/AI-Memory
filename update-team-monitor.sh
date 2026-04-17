#!/bin/bash
MONITOR_SOCK="/tmp/clawdbot-tmux-sockets/team-monitor.sock"
TEAM_SOCK="/tmp/clawdbot-tmux-sockets/team-run.sock"

# 正确的映射：监控 pane -> team session window -> 标题
mappings=(
  "team-monitor:0.0:0:🖥️  你的默认会话"
  "team-monitor:0.1:all-agents:📋 Atlas (PM)"
  "team-monitor:0.2:forge-lint:🔧 Forge (Coder)"
  "team-monitor:0.3:pixel-ui:🎨 Pixel (Designer)"
  "team-monitor:0.4:kernel-docker:⚙️  Kernel (DevOps)"
  "team-monitor:0.5:sentinel-qa:🛡️ Sentinel (QA)"
)

for line in "${mappings[@]}"; do
  IFS=':' read -r pane win title <<< "$line"
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "clear; echo -e '\033[1;33m[$title]\033[0m'; echo ''" Enter
  out=$(tmux -S "$TEAM_SOCK" capture-pane -p -t "team:$win" -S -20 2>/dev/null || echo "等待输出...")
  tmux -S "$MONITOR_SOCK" send-keys -t "$pane" "$out" Enter
done
