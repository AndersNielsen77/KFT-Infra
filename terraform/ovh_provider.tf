# =============================================================================
# OVH Proxmox Node - Central Zabbix Server
# =============================================================================
# The Zabbix server is centralized on the OVH-hosted Proxmox node (ns3079806),
# separate from the home-lab node above. Each customer gets their own Zabbix
# proxy (see modules/zabbix_proxy) running on THEIR Proxmox node, connected
# back to this server over a dedicated WireGuard tunnel. See
# docs/zabbix-monitoring.md for the full architecture and onboarding runbook.

variable "ovh_proxmox_endpoint" {
  description = "OVH Proxmox API endpoint (the central Zabbix server node)"
  type        = string
  default     = ""
}

variable "ovh_proxmox_username" {
  description = "OVH Proxmox username"
  type        = string
  default     = "root@pam"
}

variable "ovh_proxmox_password" {
  description = "OVH Proxmox password (ignored if ovh_proxmox_api_token is set)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ovh_proxmox_api_token" {
  description = "OVH Proxmox API token, format \"user@realm!tokenid=uuid\" (preferred over username/password)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ovh_node_name" {
  description = "OVH Proxmox node name"
  type        = string
  default     = "ns3079806"
}

variable "ovh_storage" {
  description = "Storage pool on the OVH node"
  type        = string
  default     = "local"
}

provider "proxmox" {
  alias     = "ovh"
  endpoint  = var.ovh_proxmox_endpoint
  api_token = var.ovh_proxmox_api_token != "" ? var.ovh_proxmox_api_token : null
  username  = var.ovh_proxmox_api_token != "" ? null : var.ovh_proxmox_username
  password  = var.ovh_proxmox_api_token != "" ? null : var.ovh_proxmox_password
  insecure  = true

  ssh {
    agent    = true
    username = "root"
  }
}
