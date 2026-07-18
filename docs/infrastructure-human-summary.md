# Infrastructure — Human Summary

> Plain-English companion to [infrastructure-target-architecture.md](./infrastructure-target-architecture.md). If a claim here disagrees with the target-architecture doc, the target-architecture doc wins.

## The Short Version

- **Two boxes do the real work.** A Proxmox host (`phoenix`) runs virtual machines and containers; a Synology NAS (`cerebro`) stores media and runs storage-adjacent services.
- **Caddy is the front door.** Everything reachable at `*.mqz.casa` goes through Caddy on phoenix, which holds a wildcard cert refreshed via Cloudflare's DNS-01 challenge — no ports open to the internet.
- **Tailscale is the back door.** From anywhere, you can reach LAN services by the same DNS names because phoenix advertises the LAN subnet to the tailnet.
- **All secrets live in one encrypted file.** `secrets.yaml` unlocked at run time via 1Password. No plaintext keys committed anywhere (see [target-architecture doc → Secret Management](./infrastructure-target-architecture.md#secret-management)).

## Hardware Reality

- **phoenix** is a small-form-factor box running Proxmox 9. It has an Intel iGPU used by Plex for QuickSync transcoding.
- **cerebro** is a Synology DS1821+ with 64 GB of RAM — enough that "keep the NAS focused on storage" is more a design preference than a resource constraint.
- **No cluster, no HA.** One of each host. If either goes down, the services it hosts go down. That is an accepted tradeoff at this scale.

## What Runs Where

- **On phoenix** — Home Assistant, Plex, Caddy, Tailscale subnet router. The rationale is spelled out in the [Service Placement Matrix](./infrastructure-target-architecture.md#target-end-state-service-placement-matrix).
- **On cerebro** — Portainer (as a UI), Channels DVR + IPTV Boss + OliveTin, Calibre, `acme.sh`. Anything that consumes or produces data that lives on the NAS.
- **Plex is the exception** — it consumes data that lives on cerebro, but runs on phoenix because it needs iGPU access. Media comes across via read-only NFS.

## Deployment Model

- **Terraform provisions machines.** VMs and LXCs on phoenix, DNS records at Cloudflare.
- **Ansible configures machines and deploys services.** One role per concern (`mqz-proxmox`, `mqz-plex`, `mqz-caddy`, `mqz-tailscale`); `run.yaml` maps roles to hosts.
- **Compose fragments live in `ansible/services/<host>/<NN-category>/compose.yaml`.** A vendored Galaxy role (`ironicbadger.docker_compose_generator`) merges them into one rendered compose file that Ansible then applies with `docker compose up`.
- **Portainer is a spectator.** It sees whatever containers Ansible starts. It never owns state.
- **Molecule + Docker for tests.** Every role has a container-based test scenario; CI runs them all on every PR.

## What Is Mostly Decided

- Proxmox on phoenix, Synology on cerebro — no plans to change either.
- Caddy for reverse proxy, Cloudflare DNS-01 for TLS — the wildcard cert eliminates per-service cert plumbing.
- Ansible + Terraform + `just` — the tool set is settled.
- Molecule as the test harness — no plans to switch back to Incus.
- 1Password + Ansible Vault for secrets.
- Portainer as UI-only; deploys through Ansible.

## What Is Still Open

Listed in one place in the [target-architecture Open Questions section](./infrastructure-target-architecture.md#open-questions). The big three:

- **Off-site backup.** Nothing leaves the LAN today.
- **VLAN segmentation.** Currently one flat subnet. See [home-network.md → Open Questions](./home-network.md#open-questions).
- **What's the future of the `mqz-phoenix` role?** It exists but nothing uses it.

## The North Star

- **A working system that is boring to operate.** Re-provisioning a host should be running a `just` recipe, waiting, and using the system again.
- **Documentation that stays honest.** If a page here contradicts what the code does, either the code or the page is broken — fix whichever is wrong in the same PR.
- **Data survives everything else.** Boxes can be replaced; the ZFS pool cannot.
