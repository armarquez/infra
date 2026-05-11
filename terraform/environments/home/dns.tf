# DNS records for mqz.casa — all internal services point to phoenix's LAN IP.
# On the home network, DNS resolves directly to 192.168.1.240 and Caddy handles routing.
# External access is via Tailscale (which routes back to the LAN).

locals {
  # Subdomains that should resolve to phoenix (Caddy handles routing from there)
  phoenix_services = ["plex", "ha", "phoenix"]
}

resource "cloudflare_record" "phoenix_services" {
  for_each = toset(local.phoenix_services)

  zone_id = var.cloudflare_zone_id
  name    = each.key
  content = var.phoenix_ip
  type    = "A"
  ttl     = 1 # Auto TTL (proxied = false keeps it short)
  proxied = false # Do NOT proxy through Cloudflare — TLS is handled by Caddy on LAN
  comment = "Managed by Terraform — points to phoenix for internal Caddy routing"
}
