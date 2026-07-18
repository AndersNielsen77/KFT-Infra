output "vm_id" {
  value = proxmox_virtual_environment_container.proxy.vm_id
}

output "hostname" {
  value = proxmox_virtual_environment_container.proxy.initialization[0].hostname
}
