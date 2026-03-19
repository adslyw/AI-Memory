#!/bin/bash
# tmux 并行 agents 演示
# 展示如何同时运行多个任务（模拟 agents）

set -euo pipefail

SOCKET_DIR="${TMPDIR:-/tmp}/clawdbot-tmux-sockets"
SOCKET="${SOCKET_DIR}/parallel-demo.sock"
mkdir -p "$SOCKET_DIR"

# 清理旧会话
tmux -S "$SOCKET" kill-server 2>/dev/null || true

echo "🚀 启动并行 agents 演示..."
echo "Socket: $SOCKET"
echo ""

# 创建 4 个工作会话
for i in 1 2 3 4; do
  SESSION="agent-$i"
  tmux -S "$SOCKET" new-session -d -s "$SESSION" -n work
  echo "✅ 创建会话: $SESSION"

  # 根据 agent ID 发送不同的任务
  case $i in
    1)
      tmux -S "$SOCKET" send-keys -t "$SESSION":0.0 "echo '🔧 Agent-1 (Forge): 开始代码优化...'; sleep 2; echo '  检查文件结构...'; sleep 1; echo '  应用重构...'; sleep 1; echo '  运行测试: ✓ 通过 12/12'; echo '✅ Agent-1 完成'" Enter
      ;;
    2)
      tmux -S "$SOCKET" send-keys -t "$SESSION":0.0 "echo '🎨 Agent-2 (Pixel): 开始 UI 设计...'; sleep 2; echo '  生成配色方案...'; sleep 1; echo '  优化布局...'; sleep 1; echo '  创建组件...'; echo '✅ Agent-2 完成'" Enter
      ;;
    3)
      tmux -S "$SOCKET" send-keys -t "$SESSION":0.0 "echo '⚙️ Agent-3 (Kernel): 部署检查...'; sleep 2; echo '  验证 Docker 配置...'; sleep 1; echo '  检查端口映射...'; sleep 1; echo '  健康检查: 通过'; echo '✅ Agent-3 完成'" Enter
      ;;
    4)
      tmux -S "$SOCKET" send-keys -t "$SESSION":0.0 "echo '🛡️ Agent-4 (Sentinel): QA 测试...'; sleep 2; echo '  运行 E2E 测试...'; sleep 1; echo '  检查边界情况...'; sleep 1; echo '  报告: 0 失败'; echo '✅ Agent-4 完成'" Enter
      ;;
  esac
done

echo ""
echo "📋 所有 agents 已启动，正在并行工作..."
echo ""

# 监控会话状态
monitor_sessions() {
  echo "=== 实时监控 (按 Ctrl+C 退出) ==="
  while true; do
    clear
    echo "⏰ $(date '+%H:%M:%S') - Agents 状态"
    echo "================================"

    tmux -S "$SOCKET" list-sessions 2>/dev/null | while read -r line; do
      SESSION=$(echo "$line" | awk '{print $1}' | cut -d: -f1)
      # 获取最近输出判断是否完成
      OUTPUT=$(tmux -S "$SOCKET" capture-pane -p -t "$SESSION":0.0 -S -5 2>/dev/null || echo "")
      if echo "$OUTPUT" | grep -q "✅ $SESSION 完成"; then
        STATUS="✅ 已完成"
      elif echo "$OUTPUT" | grep -q "正在"; then
        STATUS="🔄 运行中"
      else
        STATUS="⏳ 等待中"
      fi
      printf "%-15s %s\n" "$SESSION" "$STATUS"
    done

    echo ""
    echo "操作命令:"
    echo "  tmux -S $SOCKET attach -t agent-X   # 查看某个 agent 输出"
    echo "  tmux -S $SOCKET capture-pane -p -t agent-X:0.0 -S -50  # 获取最近50行"
    echo "  Ctrl+b d                          # 从 attach 模式退出"
    echo ""
    echo "3秒后刷新..."
    sleep 3
  done
}

# 等待几秒让任务启动
sleep 3

# 显示说明然后启动监控
echo "==========================================="
echo "📊 演示完成！现在进入监控模式"
echo "==========================================="
echo ""
echo "要查看某个 agent 的实时输出，运行："
echo "  tmux -S $SOCKET attach -t agent-1"
echo ""
echo "要查看所有会话列表："
echo "  tmux -S $SOCKET list-sessions"
echo ""
echo "要停止此演示并清理："
echo "  tmux -S $SOCKET kill-server"
echo ""

# 启动监控（可注释掉此行如果不想自动进入监控）
# monitor_sessions

echo "演示脚本执行完毕！你可以手动运行上面的命令来体验并行 agents。"
