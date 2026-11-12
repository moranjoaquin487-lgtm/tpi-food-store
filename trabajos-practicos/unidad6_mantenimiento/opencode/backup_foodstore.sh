#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

DB_NAME="foodstore"
BACKUP_DIR="backups"
LOG_DIR="logs"
TS="$(date +"%Y%m%d_%H%M%S")"
DUMP_FILE="$BACKUP_DIR/${DB_NAME}_${TS}.dump"
LOG_FILE="$LOG_DIR/backup.log"

mkdir -p "$BACKUP_DIR" "$LOG_DIR"

echo "[$(date -Is)] Iniciando respaldo de $DB_NAME en $DUMP_FILE" >> "$LOG_FILE"

pg_dump -Fc -d "$DB_NAME" -f "$DUMP_FILE"

if ! pg_restore --list "$DUMP_FILE" >/dev/null; then
  echo "[$(date -Is)] ERROR: pg_restore --list falló para $DUMP_FILE" >> "$LOG_FILE"
  exit 1
fi

echo "[$(date -Is)] OK respaldo generado y verificado: $DUMP_FILE" >> "$LOG_FILE"
exit 0
