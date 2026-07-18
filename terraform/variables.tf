variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
  # No default - must be specified in tfvars to prevent accidental prod access
}

variable "proxmox_username" {
  description = "Proxmox username"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox password (ignored if proxmox_api_token is set)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "proxmox_api_token" {
  description = "Proxmox API token, format \"user@realm!tokenid=uuid\" (preferred over username/password - revocable, least-privilege-able)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "node_name" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

variable "storage" {
  description = "Default storage for VMs/containers"
  type        = string
  default     = "local-lvm"
}

variable "bridge_main" {
  description = "Main network bridge"
  type        = string
  default     = "vmbr0"
}

variable "bridge_iot" {
  description = "IoT/secondary network bridge"
  type        = string
  default     = "vmbr1"
}

variable "environment" {
  description = "Environment (dev or prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either 'dev' or 'prod'."
  }
}

variable "truenas_memory" {
  description = "Memory allocation for TrueNAS VM in MB"
  type        = number
  default     = 2048
}

variable "ansible_ssh_public_keys" {
  description = "SSH public keys baked into new Zabbix server/proxy containers at creation, so Ansible can manage them without a separate bootstrap step"
  type        = list(string)
  default     = []
}
