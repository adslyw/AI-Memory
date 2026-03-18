#!/usr/bin/env bash
# Star Office Auto-Maintain Daemon
# Monitors Star Office service health and DeepBlue presence, auto-heals when needed
# Logs: /home/deepnight/.openclaw/workspace/memory/star-office-monitor.log

set -euo pipefail

CONFIG_FILE="/home/deepnight/.openclaw/workspace/star-office-sync.json"
START_SCRIPT="/home/deepnight/start_star_office.sh"
AGENT_ID=$(jq -r '.agentId' "$CONFIG_FILE")
JOIN_KEY=$(jq -r '.joinKey' "$CONFIG_FILE")
ENDPINT="http://127.0.0.1:19500"
LOG_FILE="/home/deepnight/.openclaw/workspace/memory/star-office-monitor.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

check_service() {
    if ! curl -s -o /dev/null -w "%{http_code}" "$ENDPINT/agents" | grep -q '^200$'; then
        return 1
    fi
    return 0
}

restart_service() {
    log "Star Office service unreachable → restarting..."
    if bash "$START_SCRIPT"; then
        log "Service restart initiated"
        sleep 5  # Give it time to come up
    else
        log "ERROR: Failed to restart service"
    fi
}

refresh_presence() {
    local detail="Auto-refresh from daemon"
    local response
    response=$(curl -s -X POST "$ENDPINT/agent-push" \
        -H "Content-Type: application/json" \
        -d "{\"agentId\":\"$AGENT_ID\",\"joinKey\":\"$JOIN_KEY\",\"state\":\"idle\",\"detail\":\"$detail\"}")
    if echo "$response" | grep -q '"ok":true'; then
        log "Presence refreshed successfully"
        return 0
    else
        log "ERROR: Presence refresh failed: $response"
        return 1
    fi
}

main() {
    log "Star Office Auto-Maintain Daemon started"
    while true; do
        # Check service health
        if ! check_service; then
            log "Service health check failed"
            restart_service
            sleep 2
            continue
        fi

        # Check DeepBlue auth status
        local auth_status
        auth_status=$(curl -s "$ENDPINT/agents" | python3 -c "
import sys, json
data = json.load(sys.stdin)
agent = [a for a in data if a.get('name') == 'DeepBlue']
print(agent[0]['authStatus'] if agent else 'not found')
" 2>/dev/null || echo "error")

        if [[ "$auth_status" == "offline" ]]; then
            log "DeepBlue auth status: offline → refreshing"
            refresh_presence
        fi

        sleep 120  # Check every 2 minutes
    done
}

# Trap termination signals
trap 'log "Daemon stopped by signal"; exit 0' INT TERM

main "$@"
