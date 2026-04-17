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
