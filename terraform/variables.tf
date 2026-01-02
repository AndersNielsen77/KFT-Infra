variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
  default     = "https://192.168.0.2:8006"
}

variable "proxmox_username" {
  description = "Proxmox username"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
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
