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

### Troubleshooting

`just ansible troubleshoot` runs a read-only diagnostic on cerebro (docker CLI availability under sudo, home dir resolution, existing containers + compose-project labels, `/volume1/docker/*` ownership, sudoers, Python venv). Output tees to `/tmp/cerebro-troubleshoot.log`. Paste that log when debugging a failed `just ansible run cerebro`.

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
