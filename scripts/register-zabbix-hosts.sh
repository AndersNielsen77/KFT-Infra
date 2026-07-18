#!/usr/bin/env bash
# Registers a list of zabbix-agent2-equipped hosts as monitored Hosts in
# Zabbix via the API, idempotently (skips any that already exist), with
# the "Linux by Zabbix agent active" template and the correct
# monitored_by (server vs proxy) assignment.
#
# Run this ON the zabbix-server container (has curl + reaches the API at
# localhost). Requires ZABBIX_ADMIN_PASSWORD in the environment.
#
# Edit the HOSTS array below for your actual fleet - this file records
# the exact rollout done on 2026-07-18 as a working reference, not a
# generic tool. Format per line: name|ip|monitored_by|proxyid|groupid
#   monitored_by: 0 = by server, 1 = by proxy
#   proxyid: the proxy's ID if monitored_by=1, else "0"
#   groupid: 2 = Linux servers, 7 = Hypervisors (see hostgroup.get for others)

set -euo pipefail

: "${ZABBIX_ADMIN_PASSWORD:?Set ZABBIX_ADMIN_PASSWORD in the environment}"
API="http://localhost/api_jsonrpc.php"
TEMPLATEID=10343  # Linux by Zabbix agent active - confirm with template.get if this drifts

TOKEN=$(curl -sS -X POST -H 'Content-Type: application/json-rpc' \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"user.login\",\"params\":{\"username\":\"Admin\",\"password\":\"$ZABBIX_ADMIN_PASSWORD\"},\"id\":1}" $API \
  | grep -oP '(?<=result":")[^"]+')
[ -n "$TOKEN" ] || { echo "Login failed"; exit 1; }

# name|ip|monitored_by|proxyid|groupid
HOSTS=(
"pve|192.168.0.2|1|1|7"
"homeassistant|192.168.0.59|1|1|2"
"unifi-tailscale|192.168.0.150|1|1|2"
"adguard|192.168.0.88|1|1|2"
"prometheus|192.168.0.105|1|1|2"
"zabbix-proxy-local-test-host|192.168.0.42|1|1|2"
"ns3079806|192.168.10.1|0|0|7"
"unifi-tailscale-ovh|192.168.10.10|0|0|2"
"reverse-proxy|192.168.10.105|0|0|2"
"nginxproxymanager|192.168.10.108|0|0|2"
"wp-nordspeed|192.168.10.210|0|0|2"
"ihg-nordspeed|192.168.10.211|0|0|2"
"rundtombiler-wp|192.168.10.213|0|0|2"
"cphweb|192.168.10.214|0|0|2"
"modded-m|192.168.10.150|0|0|2"
)

for entry in "${HOSTS[@]}"; do
  IFS='|' read -r name ip monitored_by proxyid groupid <<< "$entry"

  EXISTS=$(curl -sS -X POST -H 'Content-Type: application/json-rpc' -H "Authorization: Bearer $TOKEN" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"host.get\",\"params\":{\"filter\":{\"host\":\"$name\"}},\"id\":2}" $API \
    | grep -oP '"hostid":"[0-9]+"' || true)

  if [ -n "$EXISTS" ]; then
    echo "$name: already exists, skipping"
    continue
  fi

  RESULT=$(curl -sS -X POST -H 'Content-Type: application/json-rpc' -H "Authorization: Bearer $TOKEN" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"host.create\",\"params\":{\"host\":\"$name\",\"name\":\"$name\",\"groups\":[{\"groupid\":\"$groupid\"}],\"interfaces\":[{\"type\":1,\"main\":1,\"useip\":1,\"ip\":\"$ip\",\"dns\":\"\",\"port\":\"10050\"}],\"templates\":[{\"templateid\":\"$TEMPLATEID\"}],\"monitored_by\":$monitored_by,\"proxyid\":\"$proxyid\"},\"id\":3}" $API)
  echo "$name: $RESULT"
done
