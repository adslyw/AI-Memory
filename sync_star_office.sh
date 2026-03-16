#!/bin/bash
# Star Office Status Sync Script
# Usage: sync_star_office.sh [state] [detail]
# If state/detail omitted, auto-inferred from SESSION-STATE.md

set -euo pipefail

# 获取配置
CONFIG_FILE="${OPENCLAW_WORKSPACE:-.}/star-office-sync.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Missing star-office-sync.json in workspace" >&2
    exit 1
fi

# 解析配置
ENDPOINT=$(jq -r '.endpoint' "$CONFIG_FILE")
JOIN_KEY=$(jq -r '.joinKey' "$CONFIG_FILE")
AGENT_ID=$(jq -r '.agentId' "$CONFIG_FILE")

# 推断状态（如果未提供）
if [ $# -ge 1 ]; then
    STATE="$1"
    shift
    DETAIL="${1:-}"
else
    # 自动从 SESSION-STATE.md 推断
    SESSION_STATE_FILE="${OPENCLAW_WORKSPACE:-.}/SESSION-STATE.md"
    if [ -f "$SESSION_STATE_FILE" ]; then
        # 查找 "当前活跃任务" 部分的 "状态:" 行
        STATE_LINE=$(grep -A 10 "当前活跃任务" "$SESSION_STATE_FILE" | grep -E "状态[:：]" | head -1 || true)
        if [ -n "$STATE_LINE" ]; then
            # 提取冒号后的内容
            RAW_STATE=$(echo "$STATE_LINE" | sed -E 's/.*状态[:：][[:space:]]*//' | tr -d '\r')
            # 标准化状态
            case "$RAW_STATE" in
                *"完成"*|*"idle"*|*"待命"*|*"待命"*|*"ready"*)
                    STATE="idle"
                    ;;
                *"工作"*|*"working"*|*"coding"*|*"designing"*|*"开发"*|*"编码"*|*"实现"*|*"writing"*|*"testing"*|*"设计"*|*"准备"*|*"编写"*|*"测试"*|*"协调"*)
                    STATE="working"
                    ;;
                *"错误"*|*"error"*|*"失败"*|*"故障"*)
                    STATE="error"
                    ;;
                *"同步"*|*"等待"*|*"pending"*)
                    STATE="syncing"
                    ;;
                *)
                    STATE="idle"
                    ;;
            esac
        fi
        # 查找详情
        DETAIL_LINE=$(grep -A 10 "当前活跃任务" "$SESSION_STATE_FILE" | grep -E "详情[:：]" | head -1 || true)
        if [ -n "$DETAIL_LINE" ]; then
            DETAIL=$(echo "$DETAIL_LINE" | sed -E 's/.*详情[:：][[:space:]]*//' | tr -d '\r')
        fi
    fi
    # 默认值
    STATE="${STATE:-idle}"
    DETAIL="${DETAIL:-自动同步}"
fi

# 构建 payload
if [ -n "$DETAIL" ]; then
    PAYLOAD=$(jq -n --arg agentId "$AGENT_ID" --arg joinKey "$JOIN_KEY" --arg state "$STATE" --arg detail "$DETAIL" '{agentId:$agentId, joinKey:$joinKey, state:$state, detail:$detail}')
else
    PAYLOAD=$(jq -n --arg agentId "$AGENT_ID" --arg joinKey "$JOIN_KEY" --arg state "$STATE" '{agentId:$agentId, joinKey:$joinKey, state:$state}')
fi

# 发送请求
RESPONSE=$(curl -s -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" || echo '{"ok":false,"msg":"curl error"}')

# 检查结果
OK=$(echo "$RESPONSE" | jq -r '.ok // false')
if [ "$OK" = "true" ]; then
    echo "✅ Star Office sync: $AGENT_ID -> $STATE"
    exit 0
else
    MSG=$(echo "$RESPONSE" | jq -r '.msg // "unknown error"')
    echo "❌ Star Office sync failed: $MSG" >&2
    exit 1
fi