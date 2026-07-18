#!/usr/bin/env bash
# Installs and configures zabbix-agent2 on a host/container, handling every
# gotcha hit rolling this out across 16 targets on 2026-07-18:
#
# - Zabbix's repo restructured from 7.4 onward: packages live under
#   /<version>/release/debian/, not the older /<version>/debian/ path.
# - Installing over an existing zabbix-agent/agent2 hits an interactive
#   dpkg conffile prompt ("Modified since installation...") that hangs
#   forever with no TTY attached - handled with --force-confold.
# - Several of these containers were provisioned via community helper
#   scripts that bundled a full zabbix-agent2 7.2.x install, INCLUDING
#   plugin packages (mongodb/mssql/nvidia-gpu/ember-plus/postgresql) that
#   don't apply here. Their leftover .conf files reference now-removed
#   plugin binaries and fail agent2's config validation outright
#   ("failed to start plugin process: no such file or directory") -
#   purged unconditionally since none of these plugins are used anywhere
#   in this deployment.
# - Several also had the CLASSIC zabbix-agent (zabbix_agentd) ALSO
#   installed and running, binding port 10050 before agent2 could -
#   stopped and disabled if present.
# - Systemd's `enable --now` is a no-op if the service is ALREADY running
#   (which it often is, right after package install with default config) -
#   it does NOT reload config. Always `restart`, never just `enable --now`,
#   after changing zabbix_agent2.conf.
#
# Usage: install-zabbix-agent.sh <server_ip> <hostname>
# Run this ON the target (via pct exec, ssh, or directly on a Proxmox host).

set -euo pipefail

SERVER_IP="${1:?Usage: install-zabbix-agent.sh <server_ip> <hostname>}"
HOSTNAME_VAL="${2:?Usage: install-zabbix-agent.sh <server_ip> <hostname>}"

echo "==> Stopping any conflicting classic zabbix-agent"
systemctl stop zabbix-agent 2>/dev/null || true
systemctl disable zabbix-agent 2>/dev/null || true

echo "==> Adding the Zabbix 7.4 repo (if not already present)"
if ! dpkg -l zabbix-release 2>/dev/null | grep -q '^ii.*7\.4'; then
  command -v curl >/dev/null 2>&1 || apt-get install -y curl
  curl -sS -L https://repo.zabbix.com/zabbix/7.4/release/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.4+debian12_all.deb -o /tmp/zabbix-release-7.4.deb
  dpkg -i /tmp/zabbix-release-7.4.deb
  apt-get update
fi

echo "==> Installing zabbix-agent2"
DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confold" zabbix-agent2

echo "==> Purging leftover plugin cruft, if any (not used in this deployment)"
for plugin in ember-plus mongodb mssql nvidia-gpu postgresql; do
  dpkg -l "zabbix-agent2-plugin-$plugin" 2>/dev/null | grep -q '^.i' && \
    apt-get purge -y "zabbix-agent2-plugin-$plugin" || true
done
rm -f /etc/zabbix/zabbix_agent2.d/plugins.d/{ember,nvidia,mongodb,mssql,postgresql}.conf
dpkg --configure -a

echo "==> Configuring Server/ServerActive/Hostname"
sed -i \
  -e "s/^Server=.*/Server=$SERVER_IP/" \
  -e "s/^ServerActive=.*/ServerActive=$SERVER_IP/" \
  -e "s/^Hostname=.*/Hostname=$HOSTNAME_VAL/" \
  /etc/zabbix/zabbix_agent2.conf

/usr/sbin/zabbix_agent2 -T -c /etc/zabbix/zabbix_agent2.conf

echo "==> Enabling and restarting (not just 'enable --now' - see note above)"
systemctl enable zabbix-agent2
systemctl restart zabbix-agent2
systemctl is-active zabbix-agent2

echo "==> Done: $HOSTNAME_VAL -> $SERVER_IP"
