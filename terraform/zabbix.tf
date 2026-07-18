# =============================================================================
# Zabbix Server (Central) - hosted on the OVH node
# =============================================================================
# One of these per deployment. Every customer's Zabbix proxy (see
# modules/zabbix_proxy and zabbix_proxy_instances.tf) reports to this server
# over its own dedicated WireGuard tunnel.
#
# This resource definition matches the CT built by hand on 2026-07-18 (vm_id
# 101, 192.168.10.50/24 on vmbr1). If the container already exists, bring it
# under Terraform with:
#   terraform import proxmox_virtual_environment_container.zabbix_server ns3079806/101

resource "proxmox_virtual_environment_container" "zabbix_server" {
  provider    = proxmox.ovh
  node_name   = var.ovh_node_name
  vm_id       = 101
  description = "Zabbix Server - central monitoring, one per deployment"

  initialization {
    hostname = "zabbix-server"

    ip_config {
      ipv4 {
        address = "192.168.10.50/24"
        gateway = "192.168.10.1"
      }
    }
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 3072
    swap      = 512
  }

  disk {
    datastore_id = var.ovh_storage
    size         = 16
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr1"
  }

  features {
    keyctl  = true
    nesting = true
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    type             = "debian"
  }

  unprivileged  = true
  start_on_boot = true

  tags = ["zabbix", "monitoring", "central"]

  lifecycle {
    ignore_changes = [
      initialization,
      disk,
    ]
  }
}

output "zabbix_server_ip" {
  description = "Zabbix server address on the OVH-side private network (vmbr1)"
  value       = "192.168.10.50"
}
