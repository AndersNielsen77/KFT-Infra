provider "proxmox" {
  endpoint = var.proxmox_endpoint
  # Prefer an API token (revocable, least-privilege-able) over the root
  # account's own password when one is supplied.
  api_token = var.proxmox_api_token != "" ? var.proxmox_api_token : null
  username  = var.proxmox_api_token != "" ? null : var.proxmox_username
  password  = var.proxmox_api_token != "" ? null : var.proxmox_password
  insecure  = true

  ssh {
    agent    = true
    username = "root"
  }
}
