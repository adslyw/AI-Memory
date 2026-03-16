#!/bin/bash
# Sync all team agents to Star Office UI
# Called by cron every 30 seconds

set -euo pipefail

WORKROOT="/home/deepnight/.openclaw/workspace"
AGENTS=("pm" "coder" "designer" "devops" "qa")
LOG_FILE="/tmp/star-office-sync.log"

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

echo "[$(timestamp)] Starting sync cycle" >> "$LOG_FILE"

for AGENT in "${AGENTS[@]}"; do
    WS="$WORKROOT-$AGENT"
    SYNC_SCRIPT="$WS/sync_star_office.sh"
    if [ -x "$SYNC_SCRIPT" ]; then
        (cd "$WS" && ./sync_star_office.sh >> "$LOG_FILE" 2>&1) || echo "[$(timestamp)] $AGENT sync failed" >> "$LOG_FILE"
    else
        echo "[$(timestamp)] $AGENT: sync script not found" >> "$LOG_FILE"
    fi
done

echo "[$(timestamp)] Sync cycle complete" >> "$LOG_FILE"