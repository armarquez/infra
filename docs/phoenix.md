# Phoenix

## Overview

Phoenix is the Proxmox VE hypervisor host at `192.168.1.240`. It runs the VM and LXC workloads defined in the service placement matrix — see [infrastructure-target-architecture.md](./infrastructure-target-architecture.md) for what lives where and why.

This doc covers the one-time work of turning a fresh mini-PC into the phoenix host: hardware prep, BIOS/UEFI settings, unattended Proxmox install, first-boot verification, applying Ansible + Terraform, and the post-provisioning migrations from cerebro (interim Caddy + Tailscale subnet router).

## Hardware

**Model:** Prittec F9 Mini PC — [Amazon](https://www.amazon.com/dp/B0DNHQ9ZJ4)

| Spec | Value |
|---|---|
| CPU | Intel Core i5-13420H (8 cores / 12 threads, 12 MB cache, up to 4.6 GHz, 45 W TDP) |
| RAM (stock) | 16 GB DDR4, 1 SODIMM slot, upgradable to 64 GB |
| Storage slots | 1× M.2 2280 NVMe (512 GB pre-installed), 1× empty M.2 (up to 2 TB), 1× empty 2.5" SATA bay (up to 2 TB) |
| Networking | 2× RJ45 2.5 Gb Ethernet, WiFi 6, Bluetooth 5.2 |
| Display | Intel UHD Graphics (13th gen), HDMI 2.0, DisplayPort, full-function USB-C |
| Ports | 4× USB 3.2 Gen 1, 2× USB 2.0, 2-in-1 audio jack |
| Ships with | Windows 11 Pro (wiped during Proxmox install) |

**iGPU note:** the 13th-gen UHD Graphics is the target for Plex QuickSync transcoding via LXC passthrough. The Ansible role keeps the `i915` driver loaded on the host — see the [known-issue callout](#10-repo-config-fixes-before-first-ansible-run) below for the config change required.

## Two hardware paths

Both paths lead to the same working phoenix. Pick based on how much RAM headroom you want on day one.

| Path | RAM | Storage | Tradeoffs |
|---|---|---|---|
| **Minimum viable** | 16 GB stock | 512 GB NVMe only | Requires ZFS ARC tuning (`zfs_arc_max: 2` in phoenix.yaml) — otherwise ARC's default ~50 % of RAM leaves too little for Plex (4 GB) + HAOS (4 GB) + Caddy (0.5 GB) + Proxmox overhead |
| **Recommended** | 32 GB (or 64 GB) | 512 GB NVMe + 2 TB SATA in the 2.5" bay | Room for ZFS ARC default; SATA holds LXC/VM backups, ISO cache, occasional bulk data. Second M.2 slot stays empty for future mirror-boot or dedicated VM pool |

**When to upgrade:** RAM is easier to future-add than to re-provision under. If you're within 20 % of your target monthly, jump to 32 GB now. The 2.5" SATA is optional at install time — Proxmox will happily boot on the NVMe alone and you can add the disk later without reinstalling.

**Note on bulk storage:** phoenix does NOT need a large local disk for media. Plex mounts `/mnt/media` over NFS from cerebro (`192.168.1.250`) per the target architecture — phoenix's local storage is for VM/LXC root filesystems only.

## Networking plan

- **Cable one 2.5 Gb port** into the switch (USW Pro Max 24 — see [home-network.md](./home-network.md)). This is `vmbr0` bridge port on phoenix, static `192.168.1.240/24`, gateway `192.168.1.1`.
- **Second port stays unconfigured** — a documented decision. Revisit if VM traffic ever saturates 2.5 Gb, or if we want L2 VLAN isolation between mgmt and VM traffic (which would slot into the [#22](https://github.com/armarquez/infra/issues/22) UniFi-as-IaC work).

DNS: phoenix uses `1.1.1.1` primary, `8.8.8.8` secondary (set in phoenix.yaml `dns_servers`).

## 5. BIOS/UEFI setup

Prittec F9 uses AMI BIOS. Before flashing Proxmox to USB:

1. **Enter setup**: tap **DEL** repeatedly at POST until the BIOS UI appears.
2. **Advanced → CPU Configuration → Intel Virtualization Technology (VT-x)**: `Enabled`.
3. **Advanced → System Agent → VT-d**: `Enabled`. Required for PCIe/iGPU passthrough into LXCs and VMs.
4. **Security → Secure Boot**: `Disabled`. Proxmox's kernel modules aren't signed against the Microsoft PK.
5. **Boot → Boot Mode**: `UEFI` only (no Legacy/CSM).
6. **Boot → Boot Order**: put USB above the internal NVMe. (Alternatively, tap **F7** at POST for a one-shot boot menu.)
7. **Optional — Fast Boot**: `Disabled`. Makes catching POST easier during boot-order changes.
8. Save & exit (usually **F10**).

## 6. ISO preparation

**Known bug**: `images/scripts/generate-answer-file.sh` hardcodes `fqdn = "proxmox-template.local"`, `disk_list = ["vda"]` (virtio disk name — physical machines don't have `vda`), `filesystem = "ext4"`, and DHCP networking. None of these match phoenix. `images/http/auto.toml.example` has the correct shape but isn't wired into the generator yet. Tracked as a follow-up issue.

**Workaround for now** — manual copy + edit:

```bash
# 1. Copy the example
cp images/http/auto.toml.example images/http/auto.toml

# 2. Replace the vault-password placeholder with the real value
just ansible vault-view | grep '^initial_password:'
# copy the value and paste into auto.toml, replacing "<vault:initial_password>"

# 3. Optional: add static IP block (recommended — avoids DHCP-first-boot hunt)
cat >> images/http/auto.toml <<'EOF'

[network]
source = "from-answer"
cidr = "192.168.1.240/24"
gateway = "192.168.1.1"
dns = "1.1.1.1"
filter.INTERFACE = "eno1"   # verify after first boot; may be enp1s0
EOF

# 4. Build the ISO (script skips generate-answer-file when auto.toml already exists)
just images prepare-iso
```

Output: `images/downloads/proxmox-ve_9.1-1-auto.iso`. `images/http/auto.toml` is gitignored (contains the root password in cleartext at build time — never commit).

## 7. Flash USB

Options:

- **Balena Etcher** (cross-platform GUI) — the safest for beginners; verifies the write
- **Rufus** (Windows) — pick GPT partitioning, UEFI target
- **`dd`** (Linux/macOS) — after confirming target with `lsblk`:
  ```bash
  sudo dd if=images/downloads/proxmox-ve_9.1-1-auto.iso of=/dev/sdX bs=4M status=progress conv=fsync
  ```
  Replace `/dev/sdX` with the actual device (NOT a partition like `/dev/sdX1`). Any USB ≥ 2 GB works.

## 8. Install

1. Insert the USB into phoenix. Plug the chosen 2.5 Gb port into the switch. Power on.
2. Tap **F7** at POST to select the USB drive (or rely on the boot-order change from step 5).
3. Unattended install runs — ~5 minutes. Phoenix reboots into Proxmox VE automatically.
4. Remove the USB.
5. Verify from any LAN client: `https://192.168.1.240:8006` loads the Proxmox login. Log in as `root` with the vault password.

## 9. First-boot verification

SSH as `root` to `192.168.1.240` and run:

```bash
# Interface name — this is the one you must set correctly in phoenix.yaml
ip -o link show | awk -F': ' '{print $2}'
# Likely: eno1, enp1s0, or enp2s0. NOT ens18 (that's a Proxmox VM naming pattern).

# CPU virtualization active
lscpu | grep -E 'Virtualization|VT-x'
# Expected: "Virtualization: VT-x"

# IOMMU enabled (proves VT-d + kernel params are working)
dmesg | grep -iE 'iommu|dmar' | head
# Expected: DMAR: IOMMU enabled + IOMMU group listings

# iGPU device nodes present (proves i915 loaded)
ls /dev/dri
# Expected: card0 renderD128

# Disk layout matches expectations
lsblk
# Expected: NVMe at /dev/nvme0n1 with a ZFS pool; SATA disk (if installed) at /dev/sda
```

If any of these are missing or wrong, stop and fix before proceeding — most commonly:
- VT-d not showing IOMMU → re-check BIOS step 3
- Interface name not `eno1` → update `phoenix.yaml` `network_config` before the ansible run

## 10. Repo config fixes before first Ansible run

Two lines in `ansible/group_vars/phoenix.yaml` currently target the wrong platform. Fix in a small PR **before** running the ansible role — otherwise the first run will misconfigure IOMMU or the network bridge.

1. **`pcie_passthrough.blocklist` contains `i915`**. This conflicts with the Plex LXC iGPU passthrough plan — the `i915` driver must stay loaded on the host so the LXC can bind-mount `/dev/dri/*`. Remove the `- i915` line. (See CLAUDE.md → Intel iGPU passthrough for Plex.)

2. **`network_config` uses `bridge-ports ens18`**. `ens18` is a virtio-style interface name from VM testing; physical Prittec hardware exposes `eno1` (or `enp1s0` depending on kernel udev). Either:
   - Replace `ens18` with whatever step 9's `ip -o link show` reported, and set `configure_network: true` so ansible writes the config, OR
   - Leave `configure_network: false` (current default) and configure `vmbr0` via the Proxmox web UI: Datacenter → phoenix → System → Network → Create → Linux Bridge → Bridge ports = `eno1`, IPv4/CIDR = `192.168.1.240/24`, Gateway = `192.168.1.1`.

Both are tracked as follow-up issues.

## 11. Apply Ansible

```bash
# First run — password auth via inventory-setup.yaml (SETUP=true)
just ansible setup phoenix

# Steady-state runs — pubkey auth via inventory.yaml
just ansible run phoenix
```

The play applies two roles per `ansible/run.yaml`:
- `mqz-proxmox` — 22 tasks covering repos, users, network (if enabled), ZFS ARC (if enabled), kernel params, PCIe passthrough config, LXC templates, ksmtuned, CPU perf, fail2ban (off by default), etc. See `ansible/roles/mqz-proxmox/tasks/*.yaml`.
- `mqz-tailscale` — installs Tailscale, joins the tailnet, advertises `192.168.1.0/24` as a subnet route.

**Post-run manual step**: approve the subnet route in the [Tailscale admin console](https://login.tailscale.com/admin/machines) → phoenix → Edit route settings → toggle `192.168.1.0/24` on → Save. Same pattern documented in [docs/cerebro.md § Caddy access control](./cerebro.md#caddy-access-control).

**Retire cerebro's interim subnet-route advertisement** once phoenix is authoritative:

```bash
ssh krakoa@192.168.1.250 sudo /var/packages/Tailscale/target/bin/tailscale set --advertise-routes=
```

Then set `cerebro_tailscale_advertise_routes: []` in `ansible/roles/mqz-cerebro/defaults/main.yml` so re-runs don't re-advertise.

## 12. Terraform re-enable

The proxmox + tailscale providers were disabled in [PR #50](https://github.com/armarquez/infra/pull/50) because they'd block `tofu apply` on missing credentials while phoenix didn't exist. Now they can come back.

1. **Un-comment the `/* */` blocks** in `terraform/environments/home/main.tf` — the proxmox + tailscale entries in `required_providers` and the corresponding `provider "proxmox"` / `provider "tailscale"` blocks.
2. **Un-comment the resource files**: `haos.tf`, `lxc-caddy.tf`, `lxc-plex.tf`, and the proxmox/tailscale/haos/proxmox_node variables in `variables.tf`.
3. **Fix haos.tf pre-existing bugs** ([#59](https://github.com/armarquez/infra/issues/59)): swap `proxmox_virtual_environment_download_file` → `proxmox_download_file`; the `decompression_algorithm = "xz"` is no longer accepted by `bpg/proxmox ~> 0.70` (only `gz`/`lzo`/`zst`/`bz2`) — pick a supported release archive or add local xz decompression.
4. **Create the Proxmox API token**: log into `https://192.168.1.240:8006` → Datacenter → Permissions → API Tokens → Add. User `root@pam`, token ID `terraform`, uncheck "Privilege Separation". Save the resulting `user@pam!name=uuid-secret` string as `proxmox_terraform_api_token` in `ansible/group_vars/secrets.yaml` via `just ansible vault edit`.
5. **Create a Tailscale OAuth client** at https://login.tailscale.com/admin/settings/oauth. Scopes: `devices:core:write` (advertise routes) and `keys:write` if we want auto-auth for future nodes. Save `tailscale_oauth_client_id` + `tailscale_oauth_client_secret` in vault.
6. **Un-comment the corresponding `emit` lines** in `terraform/scripts/tf-secrets.sh`.
7. **Init + plan + apply**:
   ```bash
   just terraform init -upgrade      # picks up newly-enabled providers, updates .terraform.lock.hcl
   just terraform plan               # expect ~5 new resources
   just terraform apply
   ```

Commit the updated `.terraform.lock.hcl` — same reasoning as [PR #52](https://github.com/armarquez/infra/pull/52).

## 13. Post-provisioning migrations

Once phoenix is fully up and Terraform has created HAOS + Plex + Caddy LXCs, trigger the follow-through PRs:

- **[#58](https://github.com/armarquez/infra/issues/58) — Caddy → phoenix**. Port the compose fragment + Caddyfile pattern from `ansible/services/cerebro/09-caddy/` into phoenix's `mqz-caddy` role. Standard ports 80/443 come back (no DSM competing). Move `code` and `syncthing` entries from `cerebro_services` → `phoenix_services` in `terraform/environments/home/dns.tf` and re-apply. Retire the cerebro Caddy fragment (add `09-caddy` back to `disabled_compose_files`).
- **[#7](https://github.com/armarquez/infra/issues/7) — Plex iGPU passthrough verification**. `mqz-plex` role applies the LXC cgroup device mappings; verify with `ffmpeg -hwaccels` inside the Plex LXC.
- **Cerebro subnet-route retirement** — see step 11 above.

## 14. Known issues / gotchas

Filed as follow-up issues:

- [#71](https://github.com/armarquez/infra/issues/71) — `phoenix.yaml` `pcie_passthrough.blocklist` contains `i915` (blocks LXC iGPU passthrough)
- [#72](https://github.com/armarquez/infra/issues/72) — `phoenix.yaml` `network_config` uses `ens18` (virtio interface name; won't match physical NIC)
- [#73](https://github.com/armarquez/infra/issues/73) — `images/scripts/generate-answer-file.sh` emits a generic template rather than a phoenix-specific one
- [#59](https://github.com/armarquez/infra/issues/59) — `haos.tf` bugs (deprecated resource + unsupported `xz` decompression)

## 15. Troubleshooting

- **Unattended install stalls at "Waiting for network"** — the answer file's NIC filter didn't match. Either add a MAC-based `filter.ID_NET_NAME_MAC = "*"` catch-all, or remove the `[network]` block entirely and set static IP post-install via Proxmox web UI.
- **`https://192.168.1.240:8006` unreachable after install** — check cable, DHCP lease on the router (in case the answer file went to DHCP), or SSH in directly if you can reach the machine on the console.
- **`just ansible setup phoenix` prompts for a password that doesn't work** — the vault's `initial_password` was rotated after the ISO was built. Regenerate the ISO (`just images prepare-iso` after refreshing `auto.toml`) OR reset root password from the Proxmox console.
- **iGPU not visible under `/dev/dri`** — `i915` still blacklisted, or VT-d disabled in BIOS. Check `modprobe i915 && ls /dev/dri` and re-verify BIOS step 3.
- **Terraform plan errors on `proxmox_download_file`** — [#59](https://github.com/armarquez/infra/issues/59); the resource was renamed in `bpg/proxmox` — see step 12.3 above.

## References

- [infrastructure-target-architecture.md](./infrastructure-target-architecture.md) — service placement, roadmap, guiding principles
- [home-network.md](./home-network.md) — switch/AP topology, VLAN plan
- [cerebro.md](./cerebro.md) — Tailscale subnet-route approval flow, Caddy access-control pattern (mirrored on phoenix post-migration)
- [../CLAUDE.md](../CLAUDE.md) — iGPU passthrough decision, secret management
- [../images/README.md](../images/README.md) — Packer + Incus testing workflow (separate concern from physical-machine provisioning)
- `ansible/roles/mqz-proxmox/tasks/*.yaml` — the 22 tasks that run against phoenix
- `ansible/group_vars/phoenix.yaml` — phoenix-scoped role vars
