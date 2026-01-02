# Development Environment Setup

This guide shows how to create a local test environment for your Proxmox infrastructure.

## Option 1: Nested Proxmox VM (Recommended for full testing)

### Requirements
- 8GB+ RAM (4GB for Proxmox VM)
- CPU with virtualization support (Intel VT-x or AMD-V)
- 50GB disk space

### Step 1: Check if nested virtualization is enabled

```bash
# For Intel CPUs
cat /sys/module/kvm_intel/parameters/nested
# Should output: Y

# For AMD CPUs
cat /sys/module/kvm_amd/parameters/nested
# Should output: 1

# If not enabled, enable it:
# Intel:
echo "options kvm_intel nested=1" | sudo tee /etc/modprobe.d/kvm-intel.conf
# AMD:
echo "options kvm_amd nested=1" | sudo tee /etc/modprobe.d/kvm-amd.conf

# Reload module
sudo modprobe -r kvm_intel  # or kvm_amd
sudo modprobe kvm_intel     # or kvm_amd
```

### Step 2: Install virtualization tools

```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
```

### Step 3: Download Proxmox VE ISO

```bash
cd ~/Downloads
wget https://enterprise.proxmox.com/iso/proxmox-ve_8.3-1.iso
```

### Step 4: Create Proxmox VM

```bash
# Create disk
qemu-img create -f qcow2 ~/proxmox-test.qcow2 50G

# Start VM with VNC (you'll install Proxmox through VNC viewer)
sudo qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp 4 \
  -m 4096 \
  -cdrom ~/Downloads/proxmox-ve_8.3-1.iso \
  -drive file=~/proxmox-test.qcow2,format=qcow2 \
  -net nic -net user,hostfwd=tcp::8006-:8006,hostfwd=tcp::2222-:22 \
  -vnc :1

# In another terminal, connect with VNC
vncviewer localhost:1
```

Or use virt-manager (GUI):
```bash
virt-manager
# Create new VM → Choose ISO → Allocate 4GB RAM + 4 CPUs → 50GB disk
```

### Step 5: Install Proxmox

1. Follow the installer prompts
2. Set IP: `192.168.122.10/24` (or use DHCP)
3. Set hostname: `pve-test.local`
4. Set root password

### Step 6: Access Proxmox

After installation and reboot:
- Web UI: https://localhost:8006
- SSH: `ssh -p 2222 root@localhost`

### Step 7: Update Terraform config for testing

Create a separate tfvars file for dev:

```bash
cd /home/smd/Documents/KFT-Infra/terraform
cp terraform.tfvars terraform-dev.tfvars
```

Edit `terraform-dev.tfvars`:
```hcl
proxmox_endpoint = "https://localhost:8006"
proxmox_username = "root@pam"
proxmox_password = "your-test-password"
node_name        = "pve-test"
```

### Step 8: Test Terraform

```bash
cd /home/smd/Documents/KFT-Infra/terraform

# Initialize
terraform init

# Plan with dev config
terraform plan -var-file=terraform-dev.tfvars

# Apply only Prometheus container
terraform apply -var-file=terraform-dev.tfvars \
  -target=proxmox_virtual_environment_container.prometheus
```

---

## Option 2: LXD Containers (Faster, lighter weight)

Test Ansible roles locally without Proxmox using LXD.

### Requirements
- 4GB+ RAM
- Linux kernel with LXC support (already included)

### Step 1: Install LXD

```bash
sudo snap install lxd
sudo lxd init --auto
```

### Step 2: Create test containers

```bash
# Launch test containers
lxc launch images:debian/12 test-grafana
lxc launch images:debian/12 test-prometheus
lxc launch images:debian/12 test-adguard

# Get their IPs
lxc list
```

### Step 3: Create dev inventory

```bash
cd /home/smd/Documents/KFT-Infra/ansible
cp inventory/hosts.yml inventory/hosts-dev.yml
```

Edit `inventory/hosts-dev.yml` with LXD container IPs:
```yaml
all:
  vars:
    ansible_user: root
    ansible_python_interpreter: /usr/bin/python3

  children:
    containers:
      children:
        monitoring:
          hosts:
            grafana:
              ansible_host: 10.x.x.x  # LXD IP
            prometheus:
              ansible_host: 10.x.x.x  # LXD IP
```

### Step 4: Configure SSH access to LXD containers

```bash
# For each container
lxc exec test-grafana -- bash
apt update && apt install openssh-server python3 -y
mkdir -p /root/.ssh
exit

# Copy your SSH key
cat ~/.ssh/id_ed25519.pub | lxc exec test-grafana -- tee -a /root/.ssh/authorized_keys
```

### Step 5: Test Ansible roles

```bash
cd /home/smd/Documents/KFT-Infra/ansible

# Test connectivity
ansible -i inventory/hosts-dev.yml all -m ping

# Test a role
ansible-playbook -i inventory/hosts-dev.yml playbooks/monitoring.yml --check
```

---

## Option 3: Docker Compose (Quickest for testing containers only)

Test individual containers without Proxmox.

### Create docker-compose.yml

```yaml
version: '3.8'

services:
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./ansible/roles/prometheus/templates/prometheus.yml.j2:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus

  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"

volumes:
  grafana-data:
  prometheus-data:
```

```bash
docker-compose up -d
```

---

## Comparison

| Method | Pros | Cons | Best For |
|--------|------|------|----------|
| **Nested Proxmox** | Exact production replica, tests Terraform + Ansible | Heavy (4GB RAM), slower | Full integration testing |
| **LXD Containers** | Fast, lightweight, tests Ansible roles | Doesn't test Terraform/Proxmox | Ansible role development |
| **Docker Compose** | Fastest, easy cleanup | Only tests containers, not LXC configs | Quick service testing |

---

## Recommended Workflow

1. **Use LXD for Ansible development** - Quick iteration on roles
2. **Use Nested Proxmox for final testing** - Before deploying to production
3. **Use Git branches** - Keep dev configs separate

### Git Setup

```bash
cd /home/smd/Documents/KFT-Infra
git init
git add .
git commit -m "Initial infrastructure as code setup"

# Create dev branch
git checkout -b dev
# Make changes, test in dev environment

# When ready to deploy to production
git checkout main
git merge dev
```

---

## Quick Start: LXD Method (Recommended)

```bash
# 1. Install LXD
sudo snap install lxd
sudo lxd init --auto

# 2. Launch test container
lxc launch images:debian/12 test-prometheus
lxc exec test-prometheus -- apt update
lxc exec test-prometheus -- apt install -y openssh-server python3

# 3. Get IP and test
lxc list
ansible -i "10.x.x.x," all -m ping -u root

# 4. Test your role
ansible-playbook -i "10.x.x.x," playbooks/monitoring.yml --limit prometheus
```

Want me to help you set up LXD for quick Ansible testing?
