# Test Environment - Monitoring Stack Only
# This file deploys only Grafana and Prometheus for testing

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
