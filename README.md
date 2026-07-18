# KFT-Infra - Home Lab Infrastructure as Code

Terraform + Ansible infrastructure for deploying and managing a home lab on Proxmox VE.

## 🏗️ Architecture

**Infrastructure Stack:**
- **Proxmox VE** - Virtualization platform
- **Terraform** - Infrastructure provisioning (containers/VMs)
- **Ansible** - Configuration management (services)
- **LXC Containers** - Lightweight application containers

**Services Deployed:**
- **Monitoring**: Prometheus, Grafana, Node Exporter
- **Network**: AdGuard Home DNS blocker
- **Smart Home**: Home Assistant
- **Dashboard**: Homarr
- **Customer monitoring**: Zabbix - centralized server (OVH node) + one
  WireGuard-connected proxy per customer. See
  [`docs/zabbix-monitoring.md`](docs/zabbix-monitoring.md) for the
  architecture, onboarding runbook, and disaster recovery procedure.

## 📁 Project Structure

```
KFT-Infra/
├── terraform/                  # Infrastructure as Code
│   ├── containers.tf          # LXC container definitions (home-lab node)
│   ├── vms.tf                 # VM definitions
│   ├── provider.tf            # Proxmox provider config (home-lab node)
│   ├── ovh_provider.tf        # Second provider alias - OVH node (Zabbix server)
│   ├── zabbix.tf              # Central Zabbix server container
│   ├── zabbix_proxy_instances.tf  # One module block per customer proxy
│   ├── modules/zabbix_proxy/  # Reusable per-customer proxy container module
│   ├── variables.tf           # Variable definitions
│   └── terraform.tfvars       # Your values (not in git)
│
├── ansible/                   # Configuration Management
│   ├── inventory/
│   │   ├── test/hosts.yml    # Test environment
│   │   └── prod/hosts.yml    # Production environment
│   ├── roles/                # Service configurations
│   │   ├── wireguard_tunnel/ # Zabbix server<->proxy tunnels
│   │   ├── zabbix_server/    # Central Zabbix server
│   │   └── zabbix_proxy/     # Per-customer Zabbix proxy
│   ├── playbooks/
│   │   ├── bootstrap.yml     # Setup SSH (test env)
│   │   ├── site.yml          # Main playbook (home-lab services)
│   │   └── zabbix.yml        # Zabbix server + all customer proxies
│   └── deploy.sh             # Easy deployment script
│
├── scripts/                    # Backup/restore for stateful data Ansible can't regenerate
│   ├── export-zabbix-server.sh
│   ├── export-zabbix-proxy.sh
│   └── restore-zabbix-server.sh
│
└── docs/
    └── zabbix-monitoring.md    # Architecture, onboarding runbook, disaster recovery
```

## 🚀 Quick Start

### Prerequisites

- Proxmox VE 9.x installed
- Terraform 1.14+
- Ansible 12.0+
- Debian 12 container template in Proxmox

### 1. Clone and Configure

```bash
git clone <your-repo-url>
cd KFT-Infra

# Configure Terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Proxmox credentials

# Configure Ansible inventory
cd ../ansible
cp inventory/hosts.yml.example inventory/prod/hosts.yml
# Edit inventory/prod/hosts.yml with your IP addresses
```

### 2. Deploy Infrastructure

```bash
# Deploy containers with Terraform
cd terraform
terraform init
terraform plan
terraform apply

# Configure services with Ansible
cd ../ansible
./deploy.sh prod  # or 'test' for test environment
```

## 🔧 Usage

### Terraform Commands

```bash
cd terraform

# Initialize
terraform init

# Plan changes
terraform plan -var-file=terraform.tfvars

# Apply changes
terraform apply -var-file=terraform.tfvars

# Destroy infrastructure
terraform destroy -var-file=terraform.tfvars
```

### Ansible Commands

```bash
cd ansible

# Deploy to production
./deploy.sh prod

# Deploy to test environment
./deploy.sh test

# Deploy specific service
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml --tags grafana

# Deploy Zabbix (central server + all customer proxies)
ansible-playbook -i inventory/prod/hosts.yml playbooks/zabbix.yml

# Deploy/converge just one customer's proxy
ansible-playbook -i inventory/prod/hosts.yml playbooks/zabbix.yml --limit zabbix_proxy_<customer>
```

## 🌍 Environments

### Test Environment
- **Purpose**: Development and testing
- **Network**: Single bridge (vmbr0), DHCP
- **Bootstrap**: Automatically sets up SSH
- **IP Range**: 10.0.2.x (NAT)
- **Deployment**: `./deploy.sh test`

### Production Environment
- **Purpose**: Production home lab
- **Network**: Multiple bridges with VLANs
- **Bootstrap**: Not needed (SSH pre-configured)
- **IP Range**: 192.168.0.x (your network)
- **Deployment**: `./deploy.sh prod`

## 📋 Deployed Containers

| Service | ID | Default Port | Description |
|---------|-----|--------------|-------------|
| Home Assistant | 100 | 8123 | Smart home controller |
| AdGuard Home | 106 | 3000 | DNS ad blocker |
| Homarr | 107 | 7575 | Dashboard |
| Grafana | 109 | 3000 | Metrics visualization |
| Prometheus | 115 | 9090 | Metrics collection |
| Zabbix Proxy (local-test) | 116 | - | Reference/test customer for the Zabbix monitoring pattern |

Central Zabbix server (CT 101, Postgres + web frontend) lives on the
separate OVH node, not this one - see
[`docs/zabbix-monitoring.md`](docs/zabbix-monitoring.md).

## 🔐 Security Notes

- **Never commit** `terraform.tfvars` or inventory files with real IPs/credentials
- Use `.tfvars.example` and `.example` files as templates
- Sensitive files are in `.gitignore`
- Change default passwords after deployment
- Use SSH keys instead of passwords in production

## 🐛 Troubleshooting

### Terraform Issues

```bash
# Validate configuration
terraform validate

# Force unlock
terraform force-unlock <lock-id>
```

### Ansible Issues

```bash
# Test connectivity
ansible -i inventory/prod/hosts.yml all -m ping

# Verbose output
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml -vvv
```

## 📄 License

MIT License - Feel free to use and modify for your own home lab!
