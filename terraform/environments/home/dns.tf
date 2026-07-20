# DNS records for mqz.casa. Internal services resolve directly to their LAN
# host and Caddy on that host handles TLS + reverse proxy.
# External access is via Tailscale (which routes back to the LAN).

locals {
  # Subdomains that should resolve to phoenix (Caddy's target home; deploys
  # after phoenix's Proxmox stack is up)
  phoenix_services = ["plex", "ha", "phoenix"]

  # Interim: while phoenix isn't running Caddy yet, these subdomains resolve
  # to cerebro which hosts an interim Caddy container. When phoenix comes
  # online, move entries from here into `phoenix_services` above and re-apply.
  cerebro_services = ["code", "syncthing"]
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

resource "cloudflare_record" "cerebro_services" {
  for_each = toset(local.cerebro_services)

  zone_id = var.cloudflare_zone_id
  name    = each.key
  content = var.cerebro_ip
  type    = "A"
  ttl     = 1
  proxied = false
  comment = "Managed by Terraform — points to cerebro (interim Caddy home; migrate to phoenix later)"
}
