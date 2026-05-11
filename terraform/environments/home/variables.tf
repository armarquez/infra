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

# Cloudflare
# Reference: https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs

variable "cloudflare_api_token" {
  description = "Cloudflare API token (needs Zone:DNS:Edit permission for mqz.casa)"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for mqz.casa (found on the zone overview page)"
  type        = string
}

# Shared infrastructure values

variable "phoenix_ip" {
  description = "LAN IP of the phoenix Proxmox host"
  type        = string
  default     = "192.168.1.240"
}

variable "proxmox_node" {
  description = "Proxmox node name to deploy resources on"
  type        = string
  default     = "phoenix"
}
