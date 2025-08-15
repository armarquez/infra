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

variable "base_image" {
  type    = string
  default = "output-base/proxmox-ve-9.0-base.qcow2"
}

source "qemu" "proxmox-ve-provision" {
  # General Settings
  vm_name          = "proxmox-ve-9.0-incus.qcow2"
  output_directory = "output"

  # Use existing base image instead of ISO
  disk_image       = true
  iso_url          = var.base_image
  iso_checksum     = "none"

  # Skip boot commands - image already has OS installed
  boot_wait        = "30s"

  # Communicator Settings
  communicator           = "ssh"
  ssh_username          = "root"
  ssh_password          = var.ssh_password
  ssh_timeout           = "5m"
  ssh_handshake_attempts = 10
  ssh_wait_timeout       = "5m"
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
  name    = "proxmox-ve-provision"
  sources = ["source.qemu.proxmox-ve-provision"]

  # Quick verification that system is ready
  provisioner "shell" {
    inline = [
      "echo 'Starting provisioning from base image...'",
      "systemctl is-system-running || echo 'System is starting up...'",
      "apt-get update",
      "echo 'System ready for Ansible provisioning'"
    ]
  }

  # Ansible provisioning with corrected arguments
  provisioner "ansible" {
    playbook_file = "./ansible/provision.yaml"
    user          = "root"
    extra_arguments = [
      "--ssh-common-args=-o HostkeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa -o StrictHostKeyChecking=no",
      "-vv"
    ]
    sftp_command = "/usr/lib/sftp-server -e"
    ansible_env_vars = [
      "ANSIBLE_GATHERING=explicit", 
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ANSIBLE_SCP_IF_SSH=True"
    ]
  }
}