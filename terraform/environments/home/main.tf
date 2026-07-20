terraform {
  required_version = ">= 1.5"

  required_providers {
    # Proxmox + Tailscale disabled until phoenix is provisioned.
    # Re-enable alongside the provider blocks below and the resource files
    # (haos.tf, lxc-*.tf) once TF_VAR_proxmox_api_token / tailscale_* are wired
    # through the vault bridge.
    /*
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.70"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.17"
    }
    */
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Proxmox provider — disabled until phoenix is provisioned.
/*
provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure
}
*/

# Tailscale provider — disabled until we start managing Tailscale via Terraform.
/*
provider "tailscale" {
  oauth_client_id     = var.tailscale_oauth_client_id
  oauth_client_secret = var.tailscale_oauth_client_secret
}
*/

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
