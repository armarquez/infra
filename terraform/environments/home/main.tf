terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "2.9.14"
    }
  }
}

provider "proxmox" {
    pm_api_url = var.proxmox_api_url
    pm_user = var.proxmox_api_user
    pm_password = var.proxmox_api_pass
    pm_tls_insecure = var.proxmox_ignore_tls
}
