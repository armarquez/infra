packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "ssh_password" {
  type      = string
  default   = "changeme"
  sensitive = true
}

variable "qemu_accelerator" {
  type    = string
  default = "kvm"
}

source "qemu" "proxmox-ve-base" {
  # General Settings
  vm_name          = "proxmox-ve-9.0-base.qcow2"
  output_directory = "output-base"

  # ISO Configuration - Using prepared ProxMox VE 9.0 ISO
  iso_url          = "downloads/proxmox-ve_9.0-1-auto.iso"
  iso_checksum     = "sha256:39bc59526f1ca9384c4e0f730087e15d031c56381bb29eb1f00cadb61c809d4d"

  # Automated Install - use prepared ISO
  boot_wait        = "10s"
  boot_command     = ["<enter>"]

  # Communicator Settings
  communicator           = "ssh"
  ssh_username          = "root"
  ssh_password          = var.ssh_password
  ssh_timeout           = "20m"
  ssh_handshake_attempts = 50
  ssh_wait_timeout       = "15m"
  ssh_port              = 22
  host_port_min         = 2222
  host_port_max         = 4444

  # Hardware Settings - Optimized for Incus
  cpus             = 2
  memory           = 4096
  disk_size        = "32G"
  disk_interface   = "virtio"
  net_device       = "virtio-net"

  # QEMU specific settings
  headless         = true
  accelerator      = var.qemu_accelerator
  format           = "qcow2"
  use_default_display = false
  vnc_bind_address = "0.0.0.0"
}

build {
  name    = "proxmox-ve-base"
  sources = ["source.qemu.proxmox-ve-base"]

  # Only do minimal setup - prepare for future provisioning
  provisioner "shell" {
    inline = [
      "echo 'Creating base Proxmox VE image...'",
      # Clean up repository sources for future provisioning
      "rm -f /etc/apt/sources.list.d/ceph.list",
      "rm -f /etc/apt/sources.list.d/pve-enterprise.list", 
      "find /etc/apt/sources.list.d/ -name '*enterprise*' -delete",
      "find /etc/apt/sources.list.d/ -name '*ceph*' -delete",
      # Create clean sources.list
      "cp /etc/apt/sources.list /etc/apt/sources.list.backup",
      "cat > /etc/apt/sources.list << 'EOF'",
      "deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware",
      "deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware", 
      "deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware",
      "EOF",
      "echo 'deb http://download.proxmox.com/debian/pve trixie pve-no-subscription' > /etc/apt/sources.list.d/pve-no-subscription.list",
      # Update and install basic requirements
      "apt-get update",
      "apt-get install -y python3 python3-pip openssh-sftp-server",
      "systemctl restart ssh",
      "echo 'Base image ready for provisioning'"
    ]
  }
}