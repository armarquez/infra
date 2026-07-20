# Proxmox + Tailscale variables disabled until phoenix is provisioned and
# we start managing Tailscale via Terraform. Re-enable alongside the provider
# blocks in main.tf and the resource files (haos.tf, lxc-*.tf).
/*
# Proxmox
# Reference: https://registry.terraform.io/providers/bpg/proxmox/latest/docs

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL"
  type        = string
  default     = "https://192.168.1.240:8006"
}

variable "proxmox_api_token" {
  description = "Proxmox API token (format: user@pam!token-name=uuid-secret)"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS certificate verification (acceptable for home lab self-signed certs)"
  type        = bool
  default     = true
}

# Tailscale
# Reference: https://registry.terraform.io/providers/tailscale/tailscale/latest/docs

variable "tailscale_oauth_client_id" {
  description = "Tailscale OAuth client ID"
  type        = string
  sensitive   = true
}

variable "tailscale_oauth_client_secret" {
  description = "Tailscale OAuth client secret"
  type        = string
  sensitive   = true
}
*/

# Cloudflare
# Reference: https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs

variable "cloudflare_api_token" {
  description = "Cloudflare API token (needs Zone:DNS:Edit permission for mqz.casa)"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for mqz.casa. Not a secret — it's a stable public identifier exposed in every dashboard URL and API response. Hardcoded here so Terraform doesn't need to reach into vault for non-secret config."
  type        = string
  default     = "620d2974a3fe57accabead351efec71a"
}

# Shared infrastructure values

variable "cerebro_ip" {
  description = "LAN IP of the cerebro Synology NAS"
  type        = string
  default     = "192.168.1.250"
}

variable "phoenix_ip" {
  description = "LAN IP of the phoenix Proxmox host"
  type        = string
  default     = "192.168.1.240"
}

# Proxmox node + HAOS variables disabled until phoenix is provisioned.
/*
variable "proxmox_node" {
  description = "Proxmox node name to deploy resources on"
  type        = string
  default     = "phoenix"
}

# Home Assistant OS

variable "haos_version" {
  description = "Home Assistant OS release version — see https://github.com/home-assistant/operating-system/releases"
  type        = string
  default     = "18.1"
}

variable "haos_datastore_id" {
  description = "Proxmox storage pool where the HAOS qcow2 image is uploaded (must support 'iso' content type)"
  type        = string
  default     = "local"
}
*/
