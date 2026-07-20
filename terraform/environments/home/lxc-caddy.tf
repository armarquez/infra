# Caddy Reverse Proxy LXC
# Handles TLS termination for *.mqz.casa via Cloudflare DNS-01 challenge.
# All internal services are routed through here — nothing is exposed directly.
#
# DISABLED until phoenix is provisioned. Caddy runs interim on cerebro as a
# Docker container (see ansible/services/cerebro/09-caddy/).
/*
resource "proxmox_virtual_environment_container" "caddy" {
  description = "Caddy reverse proxy — TLS termination for *.mqz.casa"
  node_name   = var.proxmox_node
  vm_id       = 201

  unprivileged = true

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
    swap      = 0
  }

  disk {
    datastore_id = "local-lvm"
    size         = 8
  }

  network_interface {
    name     = "eth0"
    bridge   = "vmbr0"
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    type             = "debian"
  }

  initialization {
    hostname = "caddy"
  }

  startup {
    order      = 2
    up_delay   = 15
    down_delay = 10
  }
}
*/
