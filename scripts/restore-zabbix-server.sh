#!/usr/bin/env bash
# Restores a Zabbix server from a backup produced by backup-zabbix-server.sh.
#
# Run this AFTER rebuilding the CT and re-running playbooks/zabbix.yml
# against it (so the OS, packages, and an empty schema already exist) -
# this script replaces that empty schema with your real data, and puts the
# WireGuard private key back so every customer proxy can reconnect without
# needing to be re-keyed.
#
# Usage: restore-zabbix-server.sh <db_dump.sql.gz> [config.tar.gz]

set -euo pipefail

DB_DUMP="${1:?Usage: restore-zabbix-server.sh <db_dump.sql.gz> [config.tar.gz]}"
CONFIG_TAR="${2:-}"
DB_NAME="${ZABBIX_DB_NAME:-zabbix}"
DB_USER="${ZABBIX_DB_USER:-zabbix}"

echo "This will DROP and recreate the '$DB_NAME' database, replacing it"
echo "with the contents of: $DB_DUMP"
read -r -p "Continue? [y/N] " confirm
[ "$confirm" = "y" ] || { echo "Aborted."; exit 1; }

echo "==> Stopping zabbix-server"
systemctl stop zabbix-server

echo "==> Dropping and recreating the database"
sudo -u postgres dropdb "$DB_NAME"
sudo -u postgres createdb -O "$DB_USER" -E Unicode -T template0 "$DB_NAME"

echo "==> Restoring the dump"
gunzip -c "$DB_DUMP" | sudo -u postgres psql "$DB_NAME"

if [ -n "$CONFIG_TAR" ]; then
  echo "==> Restoring /etc/wireguard from $CONFIG_TAR"
  echo "    (only the WireGuard private key - /etc/zabbix config is already"
  echo "     correct from the Ansible run and shouldn't be overwritten)"
  tar xzf "$CONFIG_TAR" -C / etc/wireguard
  systemctl restart "wg-quick@wg0" || true
fi

echo "==> Starting zabbix-server"
systemctl start zabbix-server

echo "==> Done. Check: journalctl -u zabbix-server -n 50"
