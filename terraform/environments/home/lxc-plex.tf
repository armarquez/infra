# Plex Media Server LXC
#
# Intel iGPU passthrough for hardware transcoding (QuickSync):
# The bpg/proxmox provider does not yet support LXC cgroup device mappings directly.
# After `terraform apply`, Ansible handles the passthrough config by appending to
# /etc/pve/lxc/<ctid>.conf on the Proxmox host:
#
#   lxc.cgroup2.devices.allow: c 226:0 rwm   # /dev/dri/card0
#   lxc.cgroup2.devices.allow: c 226:128 rwm  # /dev/dri/renderD128
#   lxc.mount.entry: /dev/dri/card0 dev/dri/card0 none bind,optional,create=file
#   lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file
#
# The container also needs the 'video' and 'render' group GIDs mapped to match the host.

resource "proxmox_virtual_environment_container" "plex" {
  description = "Plex Media Server with Intel QuickSync hardware transcoding"
  node_name   = var.proxmox_node
  vm_id       = 200

  # Privileged is required for /dev/dri device access
  unprivileged = false

  cpu {
    cores = 4
  }

  memory {
    dedicated = 4096
    swap      = 512
  }

  disk {
    datastore_id = "local-lvm"
    size         = 20
  }

  features {
    nesting = true # needed for Docker inside LXC
  }

  network_interface {
    name     = "eth0"
    bridge   = "vmbr0"
  }

  operating_system {
    # Debian 12 CT template — auto-downloaded by mqz-proxmox
    # (ansible/roles/mqz-proxmox/tasks/22_lxc_templates.yaml)
    template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    type             = "debian"
  }

  initialization {
    hostname = "plex"
  }

  startup {
    order      = 3
    up_delay   = 60 # wait for HAOS and Caddy to start first
    down_delay = 10
  }
}
