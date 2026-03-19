#!/bin/bash
# M3U Player Database Automated Backup
# Creates daily backups of the M3U Player data directory
# Keeps last 7 days, prunes older backups

set -euo pipefail

# Configuration
PROJECT_DIR="/home/deepnight/.openclaw/workspace/projects/m3u-player"
DATA_DIR="${PROJECT_DIR}/data"
BACKUP_DIR="/home/deepnight/.openclaw/workspace/backups/m3u-player"
LOG_FILE="/home/deepnight/.openclaw/workspace/memory/backup-m3u-player.log"
RETENTION_DAYS=7

# Timestamp for this backup
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
BACKUP_FILE="m3u-player-backup-${TIMESTAMP}.tar.gz"

# Ensure backup directory exists
mkdir -p "${BACKUP_DIR}"

# Log function
log() {
    local level="$1"
    local message="$2"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Check if data directory exists
if [[ ! -d "${DATA_DIR}" ]]; then
    log "ERROR" "Data directory not found: ${DATA_DIR}"
    exit 1
fi

# Check if data has content (DB file exists)
if [[ ! -f "${DATA_DIR}/m3u-player.db" ]]; then
    log "ERROR" "Database file not found: ${DATA_DIR}/m3u-player.db"
    exit 1
fi

# Create backup
log "INFO" "Starting backup: ${BACKUP_FILE}"
if tar -czf "${BACKUP_DIR}/${BACKUP_FILE}" -C "${PROJECT_DIR}" "data" 2>/dev/null; then
    BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)
    log "INFO" "Backup created successfully (size: ${BACKUP_SIZE})"
else
    log "ERROR" "Backup creation failed"
    exit 1
fi

# Prune old backups (keep last $RETENTION_DAYS)
log "INFO" "Pruning backups older than ${RETENTION_DAYS} days"
find "${BACKUP_DIR}" -name "m3u-player-backup-*.tar.gz" -type f -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true
REMAINING=$(ls -1 "${BACKUP_DIR}"/m3u-player-backup-*.tar.gz 2>/dev/null | wc -l)
log "INFO" "Backup cleanup complete. ${REMAINING} backups retained."

log "INFO" "Backup cycle completed successfully"
