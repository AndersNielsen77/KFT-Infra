output "container_ids" {
  description = "Map of container names to their IDs"
  value = {
    homeassistant  = proxmox_virtual_environment_container.homeassistant.vm_id
    unifi_tailscale = proxmox_virtual_environment_container.unifi_tailscale.vm_id
    adguard        = proxmox_virtual_environment_container.adguard.vm_id
    homarr         = proxmox_virtual_environment_container.homarr.vm_id
    grafana        = proxmox_virtual_environment_container.grafana.vm_id
    prometheus     = proxmox_virtual_environment_container.prometheus.vm_id
  }
}

output "vm_ids" {
  description = "Map of VM names to their IDs"
  value = {
    truenas = proxmox_virtual_environment_vm.truenas.vm_id
  }
}
