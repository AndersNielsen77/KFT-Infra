## Ansible Roles Documentation

This document describes all the Ansible roles created for your homelab infrastructure.

## Role Overview

| Role | Purpose | What it manages |
|------|---------|-----------------|
| **common** | Base configuration for all containers | Installs node_exporter for Prometheus monitoring |
| **homeassistant** | Home Assistant smart home platform | Docker containers (HA + Portainer) |
| **adguard** | Network-wide ad blocking | AdGuard Home binary installation |
| **unifi** | Unifi Network Controller + Tailscale VPN | **Fixes broken Java**, installs Unifi + Tailscale |
| **homarr** | Dashboard for homelab services | Node.js/Yarn application |
| **prometheus** | Metrics collection | Prometheus server with scrape configs |
| **grafana** | Metrics visualization | Grafana with Prometheus datasource |

---

## Common Role

**Purpose:** Install monitoring agent on all containers

**What it does:**
- Installs essential packages (curl, wget, vim, htop, etc.)
- Downloads and installs node_exporter (v1.7.0)
- Creates systemd service for node_exporter
- Exposes metrics on port 9100 for Prometheus

**Variables:** None required

**Usage:**
```bash
ansible-playbook playbooks/site.yml --tags common
```

---

## Home Assistant Role

**Purpose:** Manage Home Assistant Docker installation

**What it does:**
- Installs Docker and Docker Compose
- Ensures Home Assistant container is running (`ghcr.io/home-assistant/home-assistant:stable`)
- Ensures Portainer container is running (web UI on port 9443)
- Mounts `/var/lib/docker/volumes/hass_config/_data` as config directory
- Sets timezone to Europe/Copenhagen

**Variables:**
- `ha_port` (default: 8123) - Home Assistant web UI port
- `ha_devices` (default: []) - List of device paths to pass through (e.g., `/dev/ttyACM0` for Zigbee)

**Current config location:** `/var/lib/docker/volumes/hass_config/_data/configuration.yaml`

**Access:** http://192.168.0.59:8123

**Usage:**
```bash
ansible-playbook playbooks/site.yml --tags homeassistant
```

---

## AdGuard Home Role

**Purpose:** Manage AdGuard Home DNS ad blocker

**What it does:**
- Downloads AdGuard Home binary (v0.107.52)
- Installs to `/opt/AdGuardHome/`
- Templates configuration file from existing setup
- Creates systemd service
- Listens on port 53 (DNS) and port 80/3000 (web UI)

**Variables:**
- `adguard_port` (default: 3000) - Web UI port
- `adguard_username` (default: admin)
- `adguard_password_hash` - Bcrypt hash of admin password
- `adguard_upstream_dns` (default: ['1.1.1.1', '8.8.8.8', 'https://dns10.quad9.net/dns-query'])
- `adguard_ratelimit` (default: 20) - DNS queries per second limit

**Config file:** `/opt/AdGuardHome/AdGuardHome.yaml`

**Access:** http://192.168.0.88:3000

**Usage:**
```bash
ansible-playbook playbooks/site.yml --tags adguard
```

---

## Unifi Role

**Purpose:** Fix broken Unifi Controller and manage Tailscale

**Current Issue:** ⚠️ **Unifi is BROKEN** - Java is missing!

**What it does:**
- **Installs OpenJDK 17** (fixes the broken Java dependency)
- Adds Unifi repository
- Installs/updates Unifi Network Controller
- Ensures Unifi service is running
- Installs Tailscale VPN client
- Configures both services to start on boot

**Variables:**
- `unifi_port` (default: 8443) - Unifi web UI port

**Access:** https://192.168.0.150:8443

**Tailscale Status:** Working (IP: 100.126.11.78)

**Usage - FIX UNIFI NOW:**
```bash
cd /home/smd/Documents/KFT-Infra/ansible
ansible-playbook playbooks/fix-unifi.yml
```

---

## Homarr Role

**Purpose:** Manage Homarr dashboard application

**What it does:**
- Installs Node.js 20.x and Yarn
- Ensures `/opt/homarr` directory exists
- Templates `.env` configuration file
- Runs `yarn install` and `yarn build`
- Creates systemd service
- Starts Homarr on port 7575

**Variables:**
- `homarr_port` (default: 7575)
- `homarr_url` (default: http://localhost:3000)
- `homarr_secret` - NextAuth secret key
- `homarr_disable_analytics` (default: true)
- `homarr_color_scheme` (default: dark)

**Install location:** `/opt/homarr/`
**Database:** SQLite at `/opt/homarr/database/db.sqlite`

**Access:** http://192.168.0.107:7575 (after starting container)

**Usage:**
```bash
# Start the container first
ssh root@192.168.0.2 "pct start 107"

# Then configure
ansible-playbook playbooks/site.yml --tags homarr
```

---

## Prometheus Role

**Purpose:** Install and configure Prometheus metrics server

**What it does:**
- Creates prometheus user
- Downloads Prometheus (v2.48.1)
- Installs to `/usr/local/bin/`
- Templates configuration with all your containers as scrape targets
- Creates systemd service
- Stores data in `/var/lib/prometheus/`

**Variables:**
- `prometheus_port` (default: 9090)
- `prometheus_retention` (default: 30d) - How long to keep metrics

**Scrape targets configured:**
- Proxmox host (192.168.0.2:9100)
- All LXC containers (via node_exporter)
- Home Assistant metrics API (requires token)
- AdGuard stats (requires exporter)

**Config file:** `/etc/prometheus/prometheus.yml`

**Access:** http://192.168.0.115:9090 (after creating container)

**Usage:**
```bash
# Create container with Terraform first
cd /home/smd/Documents/KFT-Infra/terraform
terraform apply -target=proxmox_virtual_environment_container.prometheus

# Start it
ssh root@192.168.0.2 "pct start 115"

# Configure
cd ../ansible
ansible-playbook playbooks/site.yml --tags prometheus
```

---

## Grafana Role

**Purpose:** Install and configure Grafana visualization

**What it does:**
- Adds Grafana APT repository
- Installs Grafana
- Configures Prometheus as default datasource
- Downloads Node Exporter dashboard (ID 1860)
- Sets up provisioning for datasources and dashboards
- Creates admin user (default: admin/admin)

**Variables:**
- `grafana_port` (default: 3000)

**Config file:** `/etc/grafana/grafana.ini`
**Dashboards:** `/var/lib/grafana/dashboards/`

**Access:** http://192.168.0.109:3000 (after starting container)

**Default credentials:** admin / admin (change on first login!)

**Usage:**
```bash
# Start the container
ssh root@192.168.0.2 "pct start 109"

# Configure
ansible-playbook playbooks/site.yml --tags grafana
```

---

## Playbook Usage

### Full Deployment (All services)
```bash
cd /home/smd/Documents/KFT-Infra/ansible
ansible-playbook playbooks/site.yml
```

### Monitoring Only (Prometheus + Grafana)
```bash
ansible-playbook playbooks/monitoring.yml
```

### Fix Unifi (Install Java and restart)
```bash
ansible-playbook playbooks/fix-unifi.yml
```

### Individual Roles
```bash
# Just install node_exporter everywhere
ansible-playbook playbooks/site.yml --limit containers --tags common

# Just configure Home Assistant
ansible-playbook playbooks/site.yml --limit homeassistant

# Just fix AdGuard config
ansible-playbook playbooks/site.yml --limit adguard --tags adguard
```

### Dry Run (Check mode)
```bash
ansible-playbook playbooks/site.yml --check --diff
```

---

## Important Notes

### 1. Unifi is Broken!
Run the fix playbook ASAP:
```bash
ansible-playbook playbooks/fix-unifi.yml
```

### 2. Stopped Containers
These need to be started manually before running playbooks:
```bash
ssh root@192.168.0.2 "pct start 107"  # Homarr
ssh root@192.168.0.2 "pct start 109"  # Grafana
```

### 3. Prometheus Container Doesn't Exist Yet
Create it with Terraform first:
```bash
cd /home/smd/Documents/KFT-Infra/terraform
terraform apply -target=proxmox_virtual_environment_container.prometheus
```

### 4. Update IPs in Inventory
After starting containers, check their IPs and update `ansible/inventory/hosts.yml`:
```bash
ssh root@192.168.0.2 "lxc-attach -n 107 -- hostname -I"  # Homarr
ssh root@192.168.0.2 "lxc-attach -n 109 -- hostname -I"  # Grafana
ssh root@192.168.0.2 "lxc-attach -n 115 -- hostname -I"  # Prometheus
```

### 5. Home Assistant API Token
To enable HA metrics in Prometheus:
1. Go to http://192.168.0.59:8123
2. Profile → Long-Lived Access Tokens → Create Token
3. Update `/etc/prometheus/prometheus.yml` on prometheus container
4. Restart Prometheus: `systemctl restart prometheus`

---

## Testing Roles Individually

```bash
# Test connectivity
ansible all -m ping

# Check what would change
ansible-playbook playbooks/site.yml --check --diff

# Run only common role on all hosts
ansible-playbook playbooks/site.yml --tags common

# Run on specific host
ansible-playbook playbooks/site.yml --limit homeassistant
```
