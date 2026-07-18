# armarquez/infra

Infrastructure as Code for a home network. Two physical hosts, Ansible for configuration, Terraform for provisioning, Molecule for testing.

*Heavily inspired by [ironicbadger/infra](https://github.com/ironicbadger/infra).*

| Hostname | Purpose |
|---|---|
| `phoenix` | Proxmox hypervisor — runs Home Assistant, Plex, Caddy, Tailscale subnet router |
| `cerebro` | Synology DS1821+ NAS — storage, media services, Portainer |

## Documentation

- **[docs/infrastructure-target-architecture.md](./docs/infrastructure-target-architecture.md)** — planning source of truth: goals, principles, service placement, decisions, roadmap.
- **[docs/infrastructure-human-summary.md](./docs/infrastructure-human-summary.md)** — plain-English companion to the architecture doc.
- **[docs/home-network.md](./docs/home-network.md)** — physical topology, IP reservations, DNS, Tailscale overlay.
- **[docs/cerebro.md](./docs/cerebro.md)** — cerebro-specific manual bootstrap notes (until issue #13 codifies them).
- **[CLAUDE.md](./CLAUDE.md)** — day-to-day operational reference: commands, workflows, testing, secrets. Also read by Claude Code when working in this repo.

## Quick Start

```bash
just bootstrap                 # Install direnv
# Restart shell, then:
direnv allow
just ansible install           # Set up Python venv + install dev deps
just install-hooks             # Install pre-commit hooks
```

Full command reference lives in [CLAUDE.md → Key Commands](./CLAUDE.md#key-commands).
