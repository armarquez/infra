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
  vm_name          = "proxmox-ve-8.2-incus.qcow2"
  output_directory = "output"

  # ISO Configuration - Using latest ProxMox VE 8.2
  iso_url          = "https://enterprise.proxmox.com/iso/proxmox-mail-gateway_8.2-1.iso"
  iso_checksum     = "sha256:2a348db5bf588450d1d47a8746d3713efc390c7fe1fc5ddf379045542999b549"

  # Unattended Install for ProxMox VE
  http_directory   = "http"
  boot_wait        = "10s"
  boot_command     = [
    "<enter><wait10s>",
    "<enter><wait5s>",
    "<enter><wait5s>",
    "<enter><wait5s>",
    "<enter><wait5s>",
    "<enter><wait5s>",
    "admin@example.com<tab>",
    "changeme<tab>",
    "changeme<tab>",
    "proxmox-template<tab>",
    "<tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><enter><wait5s>",
    "<enter><wait180s>"
  ]

  # Communicator Settings
  communicator           = "ssh"
  ssh_username          = "root"
  ssh_password          = var.ssh_password
  ssh_timeout           = "60m"
  ssh_handshake_attempts = 100
  ssh_wait_timeout       = "60m"

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

  provisioner "ansible" {
    playbook_file = "./ansible/provision.yaml"
    user          = "root"
    extra_arguments = [
      "--ssh-common-args",
      "-o HostkeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa"
    ]
  }
}
