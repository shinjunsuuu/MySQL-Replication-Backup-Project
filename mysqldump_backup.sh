#!/usr/bin/env bash
set -euo pipefail

DB_NAME=""
DB_USER=""
DB_PASS=""
BACKUP_DIR="/var/backups/mysql"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

DUMP_FILE="/root/db.sql"
mysqldump -u"$DB_USER" -p"$DB_PASS" --single-transaction --set-gtid-purged=OFF "$DB_NAME" > "$DUMP_FILE"

TAR_FILE="${BACKUP_DIR}/${DB_NAME}_${DATE}.tar.gz"
tar -czf "$TAR_FILE" -C /root db.sql
rm -f "$DUMP_FILE"

find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +7 -delete

echo "[OK] Backup completed: $TAR_FILE"