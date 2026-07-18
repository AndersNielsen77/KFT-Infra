variable "customer_name" {
  description = "Customer identifier - used for hostname and tags (lowercase, hyphenated)"
  type        = string
}

variable "node_name" {
  description = "Proxmox node this customer's proxy runs on (their own node, in real deployments)"
  type        = string
}

variable "vm_id" {
  description = "Container ID - must be unique on the target node"
  type        = number
}

variable "storage" {
  description = "Storage pool on the target node"
  type        = string
  default     = "local-lvm"
}

variable "bridge" {
  description = "Network bridge for the proxy container"
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "Optional VLAN tag"
  type        = number
  default     = null
}

variable "ip_address" {
  description = "Static IP in CIDR form, or \"dhcp\""
  type        = string
  default     = "dhcp"
}

variable "gateway" {
  description = "Gateway - required if ip_address is static, ignored for dhcp"
  type        = string
  default     = null
}

variable "cores" {
  description = "CPU cores (Zabbix's own minimum for a proxy is well under this)"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 2048
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 8
}

variable "template_file_id" {
  description = "LXC template to use - keep on Debian, Zabbix's repo layout is verified against it"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
}
