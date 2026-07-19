# Cerebro

## Ansible-managed services

Cerebro's containerised services are defined declaratively in this repo:

- Compose fragments live under `ansible/services/cerebro/<NN-name>/compose.yaml`. Each fragment is Jinja-templated (role vars available: `cerebro_docker_root`, `cerebro_puid`, `cerebro_pgid`, `cerebro_timezone`, plus per-service vars).
- The [`mqz-cerebro`](../ansible/roles/mqz-cerebro/) role runs on cerebro and (a) creates host bind-mount dirs under `/volume1/docker/<service>/`, (b) invokes `ironicbadger.docker_compose_generator` to merge fragments into a single `~/compose.yaml`, (c) runs `docker compose up` via `community.docker.docker_compose_v2`, (d) applies post-deploy service configuration via each service's REST API (Syncthing today, more to follow).
- Apply with `just ansible run cerebro`.
- Syncthing is the reference implementation of the pattern (compose fragment + REST-API-driven folder config in `group_vars/cerebro.yaml` → `syncthing_folders`). Existing services (Calibre, Channels DVR, IPTV Boss, OliveTin, Acme, Code-Server) still deploy through Portainer today; migration is tracked in issue #15.

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

#### Initial Setup

Following [this guide](https://www.technorabilia.com/portainer-as-alternative-to-synology-docker-gui/) where the key steps are:

1. Enable Container Manager
2. Enable SSH
3. SSH to Cerebro: `ssh 192.168.1.250`
4. Run the following commands:

```bash
sudo docker run -d -p 8000:8000 -p 9000:9000 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v /volume1/docker/portainer:/data portainer/portainer-ce:latest
```

#### SSO

TODO: Integrate Portainer w/ Authentik - https://chochol.io/en/software/authentik-single-sign-on-configuration-for-portainer/

### Authentik

https://github.com/goauthentik/authentik?tab=readme-ov-file

### Code-Server

https://github.com/coder/code-server/discussions/7067
