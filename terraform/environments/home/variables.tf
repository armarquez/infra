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
