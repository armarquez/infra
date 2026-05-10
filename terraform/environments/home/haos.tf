# Home Assistant OS VM
# HAOS is the officially supported HA deployment path — handles its own supervisor + add-ons.
# Requires UEFI boot. Download the HAOS QCOW2 from:
#   https://github.com/home-assistant/operating-system/releases
# and import it to Proxmox before applying:
#   qm importdisk 100 haos_ova-*.qcow2 local-lvm

resource "proxmox_virtual_environment_vm" "home_assistant" {
  name      = "home-assistant"
  node_name = var.proxmox_node
  vm_id     = 100

  description = "Home Assistant OS — smart home automation"

  cpu {
    cores = 2
    type  = "host" # expose host CPU features for best performance
  }

  memory {
    dedicated = 4096
  }

  # HAOS requires UEFI
  bios = "ovmf"

  efi_disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    type         = "4m"
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 32
    file_format  = "raw"
    iothread     = true
    ssd          = true
    discard      = "on"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  boot_order = ["scsi0"]

  # Allow HAOS to handle its own start ordering
  startup {
    order      = 1
    up_delay   = 30
    down_delay = 30
  }

  operating_system {
    type = "l26" # Linux 2.6+ kernel
  }
}
