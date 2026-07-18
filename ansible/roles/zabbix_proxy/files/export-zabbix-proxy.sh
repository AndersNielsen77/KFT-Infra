#!/usr/bin/env bash
# Backs up a customer Zabbix proxy's local state: the sqlite cache DB and
# the WireGuard tunnel identity. Run this ON the proxy container.
#
# The proxy DB is disposable cache (the server is the system of record for
# anything that matters long-term), so losing it isn't a real incident -
# but keeping the WireGuard private key means a rebuilt proxy can resume
# the SAME tunnel identity without the server needing a new peer entry.
#
# Usage: backup-zabbix-proxy.sh [backup_dir] [keep_count]

set -euo pipefail

BACKUP_DIR="${1:-/var/backups/zabbix}"
KEEP_COUNT="${2:-7}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DB_PATH="${ZABBIX_PROXY_DB:-/var/lib/zabbix/zabbix_proxy.db}"

mkdir -p "$BACKUP_DIR"

echo "==> Backing up the proxy sqlite DB"
if [ -f "$DB_PATH" ]; then
  sqlite3 "$DB_PATH" ".backup '$BACKUP_DIR/zabbix-proxy-db-$TIMESTAMP.db'"
  gzip -f "$BACKUP_DIR/zabbix-proxy-db-$TIMESTAMP.db"
else
  echo "    (no DB found at $DB_PATH, skipping)"
fi

echo "==> Archiving /etc/zabbix and /etc/wireguard"
tar czf "$BACKUP_DIR/zabbix-proxy-config-$TIMESTAMP.tar.gz" \
  --warning=no-file-changed \
  /etc/zabbix \
  /etc/wireguard

echo "==> Pruning backups older than the last $KEEP_COUNT runs"
for pattern in 'zabbix-proxy-db-*.db.gz' 'zabbix-proxy-config-*.tar.gz'; do
  # shellcheck disable=SC2012
  ls -1t "$BACKUP_DIR"/$pattern 2>/dev/null | tail -n +$((KEEP_COUNT + 1)) | xargs -r rm -f
done

echo "==> Done: $BACKUP_DIR"
