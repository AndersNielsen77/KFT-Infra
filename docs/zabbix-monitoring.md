# Zabbix Distributed Monitoring

A centralized Zabbix server (on the OVH node) with one Zabbix proxy per
customer, each connected back over its own dedicated WireGuard link. Built
and hardened on 2026-07-18; this doc is the reference for how it works, how
to onboard a new customer, and how to recover if something breaks.

## Why this shape

Customers' infrastructure lives on their own networks, often behind NAT with
no inbound access. A Zabbix proxy sits on their side, collects data locally,
and dials *out* to the central server - so nothing needs to be opened on the
customer's firewall, and the server never needs to reach in.

WireGuard carries that connection instead of exposing Zabbix's own protocol
(10051/TCP) directly to the internet per customer.

## Architecture

```
                    OVH node (ns3079806)
              ┌─────────────────────────────┐
              │   zabbix-server (CT 101)    │
              │   Postgres + nginx/php-fpm  │
              │   wg0: 10.77.0.1/24         │
              │   :51830/udp (one port,     │
              │   shared by every customer) │
              └──────────────┬──────────────┘
                              │  hub-and-spoke WireGuard
                              │  (one [Peer] stanza per customer,
                              │   all in the same 10.77.0.0/24 subnet)
              ┌───────────────┼───────────────┐
              │               │               │
     10.77.0.2/32      10.77.0.3/32     10.77.0.4/32 ...
              │               │               │
     ┌────────┴──────┐ ┌──────┴───────┐ ┌─────┴────────┐
     │ local-test     │ │ customer A   │ │ customer B   │
     │ proxy (test    │ │ proxy, on    │ │ proxy, on    │
     │ node, "customer│ │ their own    │ │ their own    │
     │ 0")            │ │ Proxmox      │ │ Proxmox      │
     └────────────────┘ └──────────────┘ └──────────────┘
```

**Key design choice:** the server runs *one* WireGuard interface and *one*
UDP port for every customer - not one port each. Onboarding a customer means
adding a `[Peer]` stanza and the next free address in `10.77.0.0/24`, never
opening another port at the OVH edge firewall. This is the difference
between a setup that scales to a handful of customers and one that scales to
however many you actually sign up.

## The "local-test" instance

The Zabbix proxy running on this home-lab node (`zabbix-proxy-local-test`,
CT 116) is **not a real customer** - it's the reference deployment that
proves the whole pattern (container provisioning, tunnel, registration,
config sync) works before it's pointed at a real customer's infrastructure.
Treat changes to its role/playbook as changes you're about to ship to every
customer, and validate against it first.

## Components

| Piece | Where it lives in this repo |
|---|---|
| Central server container | `terraform/zabbix.tf` (provider alias in `terraform/ovh_provider.tf`) |
| Per-customer proxy container | `terraform/modules/zabbix_proxy/`, instantiated in `terraform/zabbix_proxy_instances.tf` |
| WireGuard tunnel (both ends) | `ansible/roles/wireguard_tunnel/` |
| Server config (Postgres, frontend, nginx) | `ansible/roles/zabbix_server/` |
| Proxy config | `ansible/roles/zabbix_proxy/` |
| Proxy registration on the server | `ansible/roles/zabbix_server/tasks/register_proxies.yml` |
| Orchestration | `ansible/playbooks/zabbix.yml` |
| Backups | `scripts/export-zabbix-server.sh`, `scripts/export-zabbix-proxy.sh` (also installed + cron'd by the roles themselves) |
| Restore | `scripts/restore-zabbix-server.sh` |
| OVH host networking (DNAT) | `ansible/roles/ovh_host_networking/` - runs on the OVH Proxmox host itself, not a container |
| Reverse proxy vhost | `ansible/roles/zabbix_reverse_proxy/` - runs on the existing `Reverse-Proxy` CT (105) that fronts the other `*.nordspeed.dk` sites |
| Zabbix agents (monitored hosts) | `scripts/install-zabbix-agent.sh`, `scripts/register-zabbix-hosts.sh` |

## Monitored hosts (agents)

Every running container/VM on both Proxmox hosts, plus the two Proxmox
hosts themselves, run `zabbix-agent2` in **active** mode (they dial out -
no inbound port needed anywhere) and are registered with the
`Linux by Zabbix agent active` template. Local-side hosts are
`monitored_by` the `zabbix-proxy-local-test` proxy; OVH-side hosts are
monitored directly by the server, since they're already on the same
physical host.

Not included: `truenas` (its network interface is administratively down -
`link_down=1` in its VM config - not something to flip on as a side
effect of adding monitoring), anything stopped, and the `ihg.nordspeed.dk`
template container.

`scripts/install-zabbix-agent.sh <server_ip> <hostname>` does the actual
per-host install/config, and its header comment is the real gotcha
reference - worth reading before touching any of this again:

- **Zabbix 7.4's repo restructure** (same one documented above) applies
  to the agent packages too.
- **Interactive dpkg conffile prompts** hang forever with no TTY attached
  when upgrading an existing agent install - needs `--force-confold`.
- **Several containers came with a full 7.2.x agent2 + plugin bundle**
  (mongodb/mssql/nvidia-gpu/ember-plus/postgresql) from whatever
  provisioning script built them originally. None of those plugins apply
  here, and their leftover `.conf` files reference now-purged plugin
  binaries, which fails agent2's config validation outright with
  `failed to start plugin process: no such file or directory`.
- **Several also had the classic `zabbix-agent` (not agent2) already
  running**, binding port 10050 first and blocking agent2 from starting
  at all (`bind: address already in use`).
- **`systemctl enable --now` is a no-op if the service is already
  running** - which it usually is, right after package install with
  default config. It does NOT reload config. Always `restart`, not just
  `enable --now`, after changing `zabbix_agent2.conf`, or the agent keeps
  reporting under its old default Hostname (`Zabbix server`) forever.
- **One host (the OVH-side Tailscale container) uses the classic agent**
  with a `HostnameItem` directive - don't be misled by its startup log
  warning ("using [Tailscale]") into renaming the Zabbix host to match;
  that warning is about a specific item value, not the identity the agent
  actually uses for active-check requests, which is still whatever
  `Hostname=` says. Confirmed the hard way - renaming it broke active
  checks (`host [...] not found` in the server log) until reverted.

`scripts/register-zabbix-hosts.sh` records the exact host list from this
rollout (name, IP, proxy assignment, group) - a working reference to
copy from for the next batch, not a generic tool.

## Reaching the frontend

The Zabbix web UI is exposed at `http://monitoring.nordspeed.dk` through
the same reverse-proxy container as the other sites - confirmed working
end to end, publicly, right now. Two things worth knowing:

- **This reuses an existing vhost name.** `monitoring.nordspeed.dk`
  previously pointed at `192.168.10.190`, a long-dead host (confirmed
  unreachable, no CT/VM claims that IP, ARP shows `FAILED`) - repurposed
  instead of creating a new `zabbix.nordspeed.dk` subdomain, since this
  name already had a working Cloudflare DNS record (same IPs as the other
  `*.nordspeed.dk` sites) and fits Zabbix better anyway.
- **The vhost is plain HTTP**, matching the existing pattern on this proxy
  (cphweb, ihg, rundtombiler are the same) - their HTTPS, where present,
  comes from Cloudflare terminating in front of the origin, which is why
  their vhosts have no TLS block either. Add a certbot cert the same way
  those were set up if you want the origin itself to also speak TLS.

## The OVH host's own networking

Only one thing lives outside any container: the DNAT rule on the OVH
Proxmox host that routes the shared WireGuard port to the zabbix-server
CT. `ansible/roles/ovh_host_networking` manages it (idempotent - safe to
re-run). Two things it does NOT and cannot manage, since they're a
separate control plane with no SSH/API access from here:

- The OVH Edge Network Firewall rule permitting UDP 51830 inbound
- The "TCP established, ports 32768-60999" rule that fixed the host's
  outbound IPv4

Both are one-time manual steps in the OVH panel (manager.ovh.com) -
already done for this deployment, but worth knowing about if the host
ever needs to be rebuilt from scratch.

## Onboarding a new customer

1. **Terraform**: add a `module "zabbix_proxy_<customer>"` block in
   `terraform/zabbix_proxy_instances.tf` (copy the commented example). If
   they run their own Proxmox node, add a provider alias for it first (same
   pattern as `terraform/ovh_provider.tf`).
   ```
   terraform apply -target=module.zabbix_proxy_<customer>
   ```
2. **Pick the next free WireGuard address** in `10.77.0.0/24` (check the
   server's `wg_peers` list in `inventory/prod/hosts.yml` for what's taken).
   The port (`51830`) and subnet stay the same for every customer.
3. **Inventory**: add the new proxy host to `inventory/prod/hosts.yml`
   under `zabbix_proxies` (copy the commented block in
   `inventory/hosts.yml.example`), and add a matching entry to the server
   host's `wg_peers` and `zabbix_customer_proxies` lists.
4. **Generate a keypair for the new proxy** (or let the role generate one on
   first run - it prints the public key so you can copy it into the
   server's `wg_peers` list).
5. **Converge**:
   ```
   ansible-playbook -i inventory/prod/hosts.yml playbooks/zabbix.yml --limit zabbix_proxy_<customer>
   ansible-playbook -i inventory/prod/hosts.yml playbooks/zabbix.yml --limit zabbix_server
   ```
6. Confirm on the server: `Proxy "zabbix-proxy-<customer>" changed state
   from unknown to online` in `/var/log/zabbix/zabbix_server.log`.

No new port ever needs opening at the OVH Edge Network Firewall for this -
that's the whole point of the hub-and-spoke tunnel.

## Disaster recovery

**Philosophy**: Ansible is the source of truth for everything reproducible
(packages, config files, systemd units). The only things a backup needs to
carry are what Ansible *can't* regenerate - the Zabbix server's database and
the WireGuard private keys (losing a private key means every peer pointing
at it needs re-keying, which is disruptive at scale).

### If the central server CT is lost

1. Rebuild the container: `terraform apply -target=proxmox_virtual_environment_container.zabbix_server`
   (or `terraform import` first if the CT still exists but Terraform doesn't
   know about it yet).
2. Re-run `ansible-playbook playbooks/zabbix.yml --limit zabbix_server` -
   this gets you a running server with an *empty* database.
3. Restore the real data:
   ```
   scripts/restore-zabbix-server.sh /path/to/zabbix-db-<timestamp>.sql.gz \
                                     /path/to/zabbix-config-<timestamp>.tar.gz
   ```
   The config tarball restores the WireGuard private key, so every existing
   customer proxy reconnects without needing new keys.
4. Verify: every customer proxy should flip back to `online` in the server
   log within a couple of minutes (WireGuard's keepalive + Zabbix's own
   reconnect logic).

### If a customer's proxy CT is lost

Lower stakes - the proxy's local DB is disposable cache, and the server is
unaffected.

1. Rebuild via Terraform + `ansible-playbook playbooks/zabbix.yml --limit zabbix_proxy_<customer>`.
2. If you want to preserve the tunnel identity (so the server's `wg_peers`
   entry doesn't need updating), restore the WireGuard key from that
   customer's `zabbix-proxy-config-*.tar.gz` backup before starting the
   tunnel. Otherwise, generate a fresh keypair and update the server's
   `wg_peers` list with the new public key.
3. Historical data on this proxy is gone either way (it was cache, not a
   system of record) - the server keeps everything that was already synced.

### Where backups live

Both roles install their respective script to `/usr/local/bin/` and cron it
nightly, writing to `/var/backups/zabbix/` on that host by default. **That
directory only survives as long as the CT's own disk does** - sync it
off-host with whatever you already use elsewhere (rsync, rclone, PBS). This
repo doesn't prescribe a destination since that depends on what you have
available; wire it in via cron or a follow-up task once you've picked one.

## Known limits / things to revisit

- **Secrets currently live in plaintext in `inventory/prod/hosts.yml`**,
  consistent with how the rest of this repo handles credentials (gitignored,
  never committed). `ansible-vault` would be a meaningful upgrade if this
  grows past a handful of customers - the `.gitignore` already has stray
  entries for `vault-password.txt`/`.vault_pass` from an earlier setup
  attempt, suggesting it was planned before; nothing currently uses it.
- **Default Zabbix version is 7.4** (see `zabbix_version` in both roles'
  `defaults/main.yml`). Their repo layout changed between 7.0 and 7.4 -
  packages now live under `/<version>/release/debian/`, not the older
  `/<version>/debian/` path (which still exists but 404s - it's an
  unpublished placeholder, not a redirect).
- **The zabbix-server CT's disk (`/etc/zabbix`, `zabbix.conf.php`, nginx
  config) is templated by Ansible**, but if you ever hand-edit something on
  the live host (as happened during the initial build), remember to fold
  the fix back into the role - otherwise a future `terraform destroy` +
  rebuild will silently lose it.
