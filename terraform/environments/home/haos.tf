# Home Assistant OS VM
# HAOS is the officially supported HA deployment path — handles its own supervisor + add-ons.
# Requires UEFI boot.
#
# Image handling:
#   - `proxmox_virtual_environment_download_file.haos_qcow2` below fetches the
#     compressed qcow2.xz from GitHub and decompresses it into ISO storage on
#     phoenix. Idempotent (overwrite = false).
#   - For an initial VM 100 provision, add `file_id = proxmox_virtual_environment_download_file.haos_qcow2.id`
#     to the `disk` block below AND `import_from = "..."` so the qcow2 becomes
#     the boot disk on create. Left off deliberately here to avoid touching the
#     already-running VM 100 (would show as drift). Wire up on a fresh install
#     or with `lifecycle { ignore_changes = [disk] }` first.
#   - Bump `haos_version` in variables.tf (or via TF_VAR_haos_version) to pull a
#     newer HAOS release. Check https://github.com/home-assistant/operating-system/releases
resource "proxmox_virtual_environment_download_file" "haos_qcow2" {
  content_type            = "iso"
  datastore_id            = var.haos_datastore_id
  node_name               = var.proxmox_node
  url                     = "https://github.com/home-assistant/operating-system/releases/download/${var.haos_version}/haos_ova-${var.haos_version}.qcow2.xz"
  file_name               = "haos_ova-${var.haos_version}.qcow2"
  decompression_algorithm = "xz"
  overwrite               = false
}

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
