#!/usr/bin/env bash
# Backs up everything on the central Zabbix server that Ansible can't
# regenerate: the PostgreSQL database (hosts, templates, history, users,
# dashboards) and the WireGuard tunnel identity (private key + peer list).
#
# Run this ON the zabbix-server container (e.g. via cron), not from outside.
# Everything else about this host is reproducible by re-running
# playbooks/zabbix.yml against a fresh CT - see docs/zabbix-monitoring.md
# for the full restore procedure.
#
# Usage: backup-zabbix-server.sh [backup_dir] [keep_count]

set -euo pipefail

BACKUP_DIR="${1:-/var/backups/zabbix}"
KEEP_COUNT="${2:-14}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DB_NAME="${ZABBIX_DB_NAME:-zabbix}"
DB_USER="${ZABBIX_DB_USER:-zabbix}"

mkdir -p "$BACKUP_DIR"

echo "==> Dumping PostgreSQL database ($DB_NAME)"
# su, not sudo - sudo isn't installed on this minimal Debian image.
su postgres -c "pg_dump '$DB_NAME'" | gzip > "$BACKUP_DIR/zabbix-db-$TIMESTAMP.sql.gz"

echo "==> Archiving /etc/zabbix and /etc/wireguard"
tar czf "$BACKUP_DIR/zabbix-config-$TIMESTAMP.tar.gz" \
  --warning=no-file-changed \
  /etc/zabbix \
  /etc/wireguard

echo "==> Pruning backups older than the last $KEEP_COUNT runs"
for pattern in 'zabbix-db-*.sql.gz' 'zabbix-config-*.tar.gz'; do
  # shellcheck disable=SC2012
  ls -1t "$BACKUP_DIR"/$pattern 2>/dev/null | tail -n +$((KEEP_COUNT + 1)) | xargs -r rm -f
done

echo "==> Done: $BACKUP_DIR/zabbix-db-$TIMESTAMP.sql.gz"
echo "==> Done: $BACKUP_DIR/zabbix-config-$TIMESTAMP.tar.gz"
echo ""
echo "Reminder: $BACKUP_DIR only survives as long as this CT's disk does."
echo "Sync it off-host (rsync/rclone/PBS/whatever you already use elsewhere)."
