# =============================================================================
# Virtual Machines (QEMU)
# =============================================================================

# -----------------------------------------------------------------------------
# TrueNAS (VM 300)
# -----------------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "truenas" {
  node_name   = var.node_name
  vm_id       = 300
  name        = "truenas"
  description = "TrueNAS - Network Attached Storage"

  machine = "q35"
  bios    = "ovmf"

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = var.truenas_memory
    floating  = 0  # Disable ballooning
  }

  efi_disk {
    datastore_id      = var.storage
    pre_enrolled_keys = true
    type              = "4m"
  }

  disk {
    datastore_id = var.storage
    interface    = "scsi0"
    size         = 32
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  # Physical disk passthrough for storage
  # Note: scsi2 with /dev/disk/by-id/wwn-0x5000c500e884fd37 requires manual config

  network_device {
    bridge      = var.bridge_iot
    mac_address = "BC:24:11:C2:1A:5C"
    firewall    = true
    vlan_id     = 20
  }

  network_device {
    bridge      = var.bridge_main
    mac_address = "BC:24:11:42:CC:AD"
    firewall    = true
  }

  operating_system {
    type = "l26"
  }

  scsi_hardware = "virtio-scsi-single"

  on_boot = true

  tags = ["homelab", "storage"]

  lifecycle {
    ignore_changes = [
      disk,
      efi_disk,
    ]
  }
}
