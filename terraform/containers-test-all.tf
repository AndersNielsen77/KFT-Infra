# Test Environment - All Containers (except Unifi & TrueNAS)
# Simplified for test with single bridge (vmbr0)

# -----------------------------------------------------------------------------
# Home Assistant (LXC 100)
# -----------------------------------------------------------------------------
resource "proxmox_virtual_environment_container" "homeassistant" {
  node_name   = var.node_name
  vm_id       = 100
  description = "Home Assistant - Smart Home Controller"

  initialization {
    hostname = "homeassistant"
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
    swap      = 512
  }

  disk {
    datastore_id = var.storage
    size         = 16
  }

  network_interface {
    name   = "eth0"
    bridge = var.bridge_main
  }

  features {
    keyctl  = true
    nesting = true
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
    type             = "debian"
  }

  unprivileged  = true
  start_on_boot = true
  tags          = ["homelab", "smarthome", "test"]

  lifecycle {
    ignore_changes = [initialization, disk]
  }
}

# -----------------------------------------------------------------------------
# AdGuard Home (LXC 106)
# -----------------------------------------------------------------------------
resource "proxmox_virtual_environment_container" "adguard" {
  node_name   = var.node_name
  vm_id       = 106
  description = "AdGuard Home - Network-wide DNS ad blocker"

  initialization {
    hostname = "adguard"
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
    swap      = 512
  }

  disk {
    datastore_id = var.storage
    size         = 10
  }

  network_interface {
    name   = "eth0"
    bridge = var.bridge_main
  }

  features {
    keyctl  = true
    nesting = true
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
    type             = "debian"
  }

  unprivileged  = true
  start_on_boot = true
  tags          = ["homelab", "network", "dns", "test"]

  lifecycle {
    ignore_changes = [initialization, disk]
  }
}

# -----------------------------------------------------------------------------
# Homarr Dashboard (LXC 107)
# -----------------------------------------------------------------------------
resource "proxmox_virtual_environment_container" "homarr" {
  node_name   = var.node_name
  vm_id       = 107
  description = "Homarr - Home Dashboard"

  initialization {
    hostname = "homarr"
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
    swap      = 512
  }

  disk {
    datastore_id = var.storage
    size         = 8
  }

  network_interface {
    name   = "eth0"
    bridge = var.bridge_main
  }

  features {
    keyctl  = true
    nesting = true
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
    type             = "debian"
  }

  unprivileged  = true
  start_on_boot = false
  tags          = ["homelab", "dashboard", "test"]

  lifecycle {
    ignore_changes = [initialization, disk]
  }
}

# -----------------------------------------------------------------------------
# Grafana (LXC 109)
# -----------------------------------------------------------------------------
resource "proxmox_virtual_environment_container" "grafana" {
  node_name   = var.node_name
  vm_id       = 109
  description = "Grafana - Metrics Visualization"

  initialization {
    hostname = "grafana"
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
    swap      = 512
  }

  disk {
    datastore_id = var.storage
    size         = 4
  }

  network_interface {
    name   = "eth0"
    bridge = var.bridge_main
  }

  features {
    keyctl  = true
    nesting = true
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
    type             = "debian"
  }

  unprivileged  = true
  start_on_boot = true
  tags          = ["homelab", "monitoring", "test"]

  lifecycle {
    ignore_changes = [initialization, disk]
  }
}

# -----------------------------------------------------------------------------
# Prometheus (LXC 115)
# -----------------------------------------------------------------------------
resource "proxmox_virtual_environment_container" "prometheus" {
  node_name   = var.node_name
  vm_id       = 115
  description = "Prometheus - Metrics Collection"

  initialization {
    hostname = "prometheus"
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 1024
    swap      = 512
  }

  disk {
    datastore_id = var.storage
    size         = 20
  }

  network_interface {
    name   = "eth0"
    bridge = var.bridge_main
  }

  features {
    keyctl  = true
    nesting = true
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
    type             = "debian"
  }

  unprivileged  = true
  start_on_boot = true
  tags          = ["homelab", "monitoring", "test"]

  lifecycle {
    ignore_changes = [initialization, disk]
  }
}
