packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
    ansible = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/ansible"
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

source "qemu" "proxmox-ve" {
  # General Settings
  vm_name          = "proxmox-ve-9.0-incus.qcow2"
  output_directory = "output"

  # ISO Configuration - Using latest ProxMox VE 9.0
  # iso_url          = "https://enterprise.proxmox.com/iso/proxmox-ve_9.0-1.iso"
  # iso_checksum     = "sha256:228f948ae696f2448460443f4b619157cab78ee69802acc0d06761ebd4f51c3e"
  iso_url          = "downloads/proxmox-ve_9.0-1-auto.iso"
  iso_checksum     = "sha256:39bc59526f1ca9384c4e0f730087e15d031c56381bb29eb1f00cadb61c809d4d"

  # Automated Install - fallback to preseed-style approach
  http_directory   = "http"
  boot_wait        = "5s"
  boot_command     = [
    # Select the installation option and wait for the system to load
    "<enter><wait30s>",
    # Accept license and proceed through installer
    "<enter><wait5s>",          # Country selection
    "<enter><wait5s>",          # Timezone 
    "<enter><wait5s>",          # Keyboard layout
    "changeme<tab>",            # Root password
    "changeme<tab>",            # Confirm password
    "admin@example.com<tab>",   # Email
    "proxmox-template<tab>",    # Hostname
    "<enter><wait5s>",          # Network auto-config
    "<enter><wait5s>",          # Disk selection 
    "<enter><wait5s>",          # Filesystem selection
    "<enter><wait5s>",          # Continue with installation
    "<enter><wait300s>"         # Wait for installation to complete
  ]

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
  name    = "proxmox-ve-for-incus"
  sources = ["source.qemu.proxmox-ve"]

  # Prepare system for Ansible provisioning  
  provisioner "shell" {
    inline = [
      "echo 'Preparing system for Ansible...'",
      # List current repository files for debugging
      "echo 'Current repository files:'",
      "find /etc/apt/sources.list.d/ -name '*.list' -exec basename {} \\;",
      # Remove all enterprise repository sources that require subscription
      "rm -f /etc/apt/sources.list.d/ceph.list",
      "rm -f /etc/apt/sources.list.d/pve-enterprise.list", 
      "find /etc/apt/sources.list.d/ -name '*enterprise*' -delete",
      "find /etc/apt/sources.list.d/ -name '*ceph*' -delete",
      # Create a minimal working sources.list without enterprise repos
      "cp /etc/apt/sources.list /etc/apt/sources.list.backup",
      "cat > /etc/apt/sources.list << 'EOF'",
      "deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware",
      "deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware", 
      "deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware",
      "EOF",
      # Add no-subscription repository
      "echo 'deb http://download.proxmox.com/debian/pve trixie pve-no-subscription' > /etc/apt/sources.list.d/pve-no-subscription.list",
      # Update package lists
      "apt-get update",
      "apt-get install -y python3 python3-pip openssh-sftp-server",
      "systemctl restart ssh",
      "echo 'System ready for Ansible provisioning'"
    ]
  }

  # Wait a bit for services to stabilize
  provisioner "shell" {
    pause_before = "10s"
    inline = ["echo 'Services stabilized, ready for Ansible'"]
  }

  provisioner "ansible" {
    playbook_file = "./ansible/provision.yaml"
    user          = "root"
    extra_arguments = [
      "--ssh-common-args",
      "-o HostkeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa",
      "-o StrictHostKeyChecking=no",
      "-vv"
    ]
    sftp_command = "/usr/lib/openssh/sftp-server -e"
  }
}
