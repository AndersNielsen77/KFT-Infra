# Reusable per-customer Zabbix proxy container.
# One instantiation of this module = one customer's monitoring collector.
# See ../../zabbix_proxy_instances.tf for how instances are declared, and
# docs/zabbix-monitoring.md for the onboarding runbook.

resource "proxmox_virtual_environment_container" "proxy" {
  node_name   = var.node_name
  vm_id       = var.vm_id
  description = "Zabbix Proxy - customer: ${var.customer_name}"

  initialization {
    hostname = "zabbix-proxy-${var.customer_name}"

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.ip_address == "dhcp" ? null : var.gateway
      }
    }
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
    swap      = 512
  }

  disk {
    datastore_id = var.storage
    size         = var.disk_size
  }

  network_interface {
    name    = "eth0"
    bridge  = var.bridge
    vlan_id = var.vlan_id
  }

  features {
    keyctl  = true
    nesting = true
  }

  operating_system {
    template_file_id = var.template_file_id
    type             = "debian"
  }

  unprivileged  = true
  start_on_boot = true

  tags = ["zabbix", "proxy", "customer-${var.customer_name}"]

  lifecycle {
    ignore_changes = [
      initialization,
      disk,
    ]
  }
}
