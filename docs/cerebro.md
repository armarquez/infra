# Cerebro

## Ansible-managed services

Cerebro's containerised services are defined declaratively in this repo:

- Compose fragments live under `ansible/services/cerebro/<NN-name>/compose.yaml`. Each fragment is Jinja-templated (role vars available: `cerebro_docker_root`, `cerebro_puid`, `cerebro_pgid`, `cerebro_timezone`, plus per-service vars).
- The [`mqz-cerebro`](../ansible/roles/mqz-cerebro/) role runs on cerebro and (a) creates host bind-mount dirs under `/volume1/docker/<service>/`, (b) invokes `ironicbadger.docker_compose_generator` to merge fragments into a single `~/compose.yaml`, (c) runs `docker compose up` via `community.docker.docker_compose_v2`, (d) applies post-deploy service configuration via each service's REST API (Syncthing today, more to follow).
- Apply with `just ansible run cerebro`.
- Syncthing is the reference implementation of the pattern (compose fragment + REST-API-driven folder config in `group_vars/cerebro.yaml` → `syncthing_folders`). Existing services (Calibre, Channels DVR, IPTV Boss, OliveTin, Acme, Code-Server) still deploy through Portainer today; migration is tracked in issue #15.

### One-time bootstrap on a fresh cerebro

Run these once as `krakoa` via SSH before the first `just ansible run cerebro`. Codifying this into an Ansible `raw`-module play is a follow-up.

1. **Groups + sudo** (via DSM Control Panel UI on `krakoa` user): join `administrators` and `docker` groups.
2. **Passwordless sudo** (via SSH as `krakoa`):
   ```bash
   sudo tee /etc/sudoers.d/krakoa <<< 'krakoa ALL=(ALL) NOPASSWD: ALL'
   sudo chmod 440 /etc/sudoers.d/krakoa
   ```
3. **Tight SSH permissions** (Synology's default home dir mode blocks pubkey auth):
   ```bash
   chmod 700 ~ ~/.ssh
   chmod 600 ~/.ssh/authorized_keys
   ```
4. **Python 3.11 via uv** (DSM ships 3.8; ansible-core needs 3.9+):
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   source $HOME/.local/bin/env
   uv python install 3.11
   uv venv --python 3.11 ~/.venvs/ansible
   uv pip install --python ~/.venvs/ansible/bin/python docker
   ```
   `ansible/inventories/home-network/inventory.yaml` already points `ansible_python_interpreter` at the resulting venv.

### Migration status

Before Ansible touched cerebro, services ran via a mix of Portainer, DSM's built-in Container Manager (Projects + individual containers), and manual `docker run`. Migration is phased — each service moves under Ansible one at a time, with a per-service takeover task that removes the pre-Ansible container before compose brings up the identical stack. This preserves bind-mounted data.

Owners of existing `/volume1/docker/<service>/` data (confirmed via `id`):

- `krakoa` = 1032 (SSH user, Ansible connects as this)
- `boogey` = 1026 (originally owned calibre, olivetin, acme-sh)
- `the-collector` = 1028 (originally owned eplustv, iptv-boss, and the nzbget/deluge/sonarr/radarr "the-collector" stack)

Current fragment / service state:

| Fragment | Currently running as | Ansible status | Blocker |
|---|---|---|---|
| `01-portainer` | `portainer` | **Enabled** | — |
| `40-syncthing` | `syncthing` | **Enabled** — GUI reached via Caddy at `https://syncthing.mqz.casa:4443`. Post-deploy `tasks/syncthing.yml` enforces GUI authentication (user `syncthing_gui_user`, password `syncthing_gui_password` from vault) via the REST API — the fragment runs with `network_mode: host` so the default LAN-open GUI would otherwise be reachable without any credentials. | — |
| `00-acme-sh` | `acme.sh` (Portainer) | disabled | Cloudflare + certadmin secrets needed in vault |
| `10-channels-dvr` | `channels-dvr-eplustv-1`, `pluto-for-channels` | **Enabled** — pre-Ansible containers removed on first run, replaced by compose | — |
| `11-iptv-boss` | `iptv-boss-iptvboss-1` | **Enabled** — pre-Ansible container removed on first run, replaced by compose | — |
| `12-olivetin-channels` | `olivetin`, `static-file-server` (Portainer) | disabled | broken `version: '3.9'` stanza + `${PORTAINER_TOKEN}` interpolation |
| `20-codeserver` | `codeserver` | **Enabled** — `codeserver_password` + `codeserver_sudo_password` in vault; reached via Caddy at `https://code.mqz.casa:4443`. Container port 8443 is published to `127.0.0.1` only so direct `:8443` bypass isn't reachable from the LAN. | — |
| `30-calibre` | `calibre-web-automated` | **Enabled** — pre-Ansible container removed on first run, replaced by compose (bind-mount data preserved) | — |
| `50-the-collector` | `nzbget`, `deluge`, `sonarr`, `radarr` | **Enabled** — pre-Ansible containers removed on first run, replaced by compose. `nzbget_password` templated from vault. | — |
| `13-channels-remote` | `channels-remote` | **Enabled** — stateless takeover; project label was `channels-app-remote-plus` | — |
| `14-adbtuner` | `adbtuner` | **Enabled** — takeover + one-time migration of the Docker named volume `adbtuner_config` to a bind mount at `/volume1/docker/adbtuner/config` | — |
| `09-caddy` | `caddy` | **Enabled** — interim TLS reverse proxy on cerebro. Runs with `network_mode: host` on ports **8880 (HTTP)** and **4443 (HTTPS)** because DSM's own nginx owns 80/443. Access restricted to LAN + Tailscale — see [Caddy access control](#caddy-access-control) below. Migrate to phoenix (which will get 80/443) long-term. | — |

The `disabled_compose_files` list in `ansible/group_vars/cerebro.yaml` is the switch — remove an entry once the corresponding takeover is written.

### Caddy access control

Caddy on cerebro enforces an IP allowlist at the site level — requests whose source IP is not in one of `cerebro_caddy_allowed_cidrs` (default `192.168.1.0/24`, `100.64.0.0/10`) get a 403. This is defense-in-depth: the DNS records for `*.mqz.casa` are public, so the allowlist prevents accidental exposure if the network edge were ever misconfigured.

Two runtime prerequisites for the allowlist to work correctly:

- **Host networking**: the compose fragment sets `network_mode: host` so Caddy sees real client source IPs. Under DSM's default bridge networking, the source IP is rewritten to the Docker bridge gateway (~172.17.0.1) and every legit client would be blocked.
- **Cerebro advertises `192.168.1.0/24` as a Tailscale subnet route** (managed by `roles/mqz-cerebro/tasks/tailscale.yml`). Off-LAN tailscale clients keep using the same `https://code.mqz.casa:4443` URL — traffic reaches cerebro over the tailnet as if it were on-LAN. **First-time-only manual step**: approve the route in the [Tailscale admin console](https://login.tailscale.com/admin/machines) → cerebro → Edit route settings.

When Caddy moves to phoenix later, the same allowlist pattern applies; the subnet-route advertisement moves to phoenix and the cerebro-side value in `cerebro_tailscale_advertise_routes` empties out.

### Troubleshooting

The `just ansible troubleshoot` recipe is a shared entry point for ad-hoc diagnostics — it invokes whichever script is currently useful. Today it points at `scripts/troubleshoot-cerebro.sh`, a read-only dump of docker CLI availability under sudo, home dir resolution, existing containers + compose-project labels, `/volume1/docker/*` ownership, sudoers, and Python venv state. Output tees to `/tmp/cerebro-troubleshoot.log`. Paste that log when debugging a failed `just ansible run cerebro`.

As focus shifts to other hosts, swap the script path in the recipe rather than adding new recipes.

## Networking

- Cerebro's IP address is staticly defined in the router - `192.168.1.250`

## Software

Below is some notes on important software that I setup on Cerebro.
Ideally, these notes are translated into code.

### Tailscale

https://tailscale.com/kb/1131/synology

- Install Tailscale via package manager
- Setup automated updated via scheduled tasks
- Create a TUN device for outbound connections

Setup TLS certs via Tailscale - https://sim642.eu/blog/2024/08/11/tailscale-https-certificate-on-synology-nas/

### Portainer

Managed by the `mqz-cerebro` role via the [`00-portainer` compose fragment](../ansible/services/cerebro/00-portainer/compose.yaml). Bootstrap once per fresh cerebro install:

1. Enable Container Manager (DSM Package Center).
2. Enable SSH (DSM Control Panel → Terminal & SNMP).
3. Ensure the DSM admin user (see `ansible/inventories/home-network/inventory.yaml` → `ansible_user`) is a member of the `docker` group.
4. Run `just ansible run cerebro` from the dev box. The `mqz-cerebro` role will (a) create `/volume1/docker/portainer/`, (b) detect and remove any pre-existing manually-created `portainer` container (data volume preserved), (c) bring up Portainer via compose on ports 8000, 9000, and 9443.

Portainer's data (admin account, stacks, environments) is bind-mounted from `/volume1/docker/portainer` and survives container re-creation.

**Admin credentials:** on a truly fresh install (no `/volume1/docker/portainer` yet), Portainer prompts for an admin account on first visit to `http://192.168.1.250:9000`. If migrating from the previous manual install, existing credentials keep working.

#### SSO

TODO: Integrate Portainer w/ Authentik - https://chochol.io/en/software/authentik-single-sign-on-configuration-for-portainer/

### Authentik

https://github.com/goauthentik/authentik?tab=readme-ov-file

### Code-Server

https://github.com/coder/code-server/discussions/7067
