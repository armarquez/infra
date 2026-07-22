# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**SECURITY WARNING**: Never include actual passwords, secrets, or sensitive credentials in this file. Always use placeholder values like `<encrypted_password>` when documenting credential structures.

## Overview

Home infrastructure repository using Infrastructure as Code for two physical machines:
- `phoenix` — Proxmox hypervisor host (192.168.1.240)
- `cerebro` — Synology NAS / storage-adjacent services host (192.168.1.250)

**Tools**: Ansible (config management), OpenTofu (VM/LXC provisioning + DNS), Just (command runner), 1Password CLI + Ansible Vault (secrets), Molecule + Docker (Ansible testing), GitHub Actions (CI).

**Architecture docs**: [docs/infrastructure-target-architecture.md](./docs/infrastructure-target-architecture.md) is the source of truth for service placement, guiding principles, decisions, and roadmap. This file (CLAUDE.md) covers day-to-day operational commands and workflows.

## Toolchain philosophy

**Minimal host deps, pin the rest in-repo.** A fresh clone should be productive with only these installed on the host:

1. `git`
2. `direnv`
3. `mise`
4. 1Password CLI (`op` or `op.exe` on WSL)

Everything else — `just`, `opentofu`, `yq`, and any future CLI tooling — is pinned in `mise.toml` at repo root and installed via `mise install`. When adding a new tool to the workflow, add it to `mise.toml` rather than documenting a separate install step. When bumping a version, look up the current stable release on GitHub (do not guess from memory).

Corollary: don't wrap install of a new tool in a `just install-<tool>` recipe unless the tool cannot be handled by mise (mise's registry is broad — `mise registry | grep <tool>` first).

## Pre-commit Hooks

`.pre-commit-config.yaml` at repo root runs automatically on every `git commit`:
- **trailing-whitespace** — removes trailing spaces (autofix)
- **end-of-file-fixer** — ensures files end with a newline (autofix)
- **check-yaml** — validates YAML syntax
- **check-merge-conflict** — blocks committing unresolved conflict markers

`ansible-lint` is **not** in pre-commit (too slow for a commit hook) — it runs in CI only.

```bash
just install-hooks              # Install hooks into .git/hooks/ (once per clone)
just lint-all                   # Run all hooks against every file (useful after updating hooks config)
```

The `pre-commit` binary is installed as part of `just ansible install`.

## Branch and PR Workflow

**Never commit directly to `main`.** All work goes through a short-lived branch and a PR. Main is protected by a GitHub Ruleset that requires:
- A PR to be open (no direct pushes)
- All CI checks to pass (Ansible Lint + all Molecule jobs)
- No required approvals (solo dev — self-merge once CI is green)

### Branch naming
Use `type/short-description`:
- `feat/` — new role, new service, new Terraform resource
- `fix/` — bug fix, broken config, failed lint
- `infra/` — repo tooling, CI, justfile, hooks, docs

### Standard PR flow
```bash
git checkout -b feat/my-thing     # create branch off current main
# ... do work, commit ...
git push -u origin feat/my-thing  # push branch
gh pr create --title "..." --body "..."  # open PR
gh run watch                      # wait for CI
gh pr merge --squash --delete-branch  # merge once green
```

### Squash merge
Always squash-merge PRs so main history is one commit per feature/fix. Use `gh pr merge --squash --delete-branch` to merge and clean up the branch in one step.

## CI Discipline

**Always run tests locally first. GitHub Actions minutes are a limited resource — burning CI runs on failures that could be caught locally wastes quota and slows the feedback loop.**

Rule: if you touched Ansible roles, run lint and molecule locally before pushing. Only push when local tests pass. Use CI as a final gate, not a debugging tool.

```bash
# Before every push — run both checks locally:
just ansible lint                          # ansible-lint on all roles
just ansible molecule-test ROLE=<role>     # molecule for any role you touched

# After pushing — verify CI passed:
gh run list --limit 5          # see recent runs
gh run watch                   # stream the current run live
```

If lint or molecule fails locally, fix it before pushing. After a push, wait for CI to complete and resolve any failures before considering the work done.

## GitHub Issues Workflow

**All planned work must be tracked as GitHub issues — including tasks that will be completed immediately.** Issues act as a resumable checkpoint: if a plan session is interrupted mid-way, the open issues show exactly where work stopped.

```bash
# Create an issue
gh issue create --title "Title" --body "Description" --label "enhancement"

# List open issues
gh issue list

# Close an issue when work is complete
gh issue close <number>

# View an issue
gh issue view <number>
```

**At the start of any plan session**: create a GitHub issue for every task in the plan before implementing anything. Close each issue immediately as its task is completed. This way, if the session is interrupted, the remaining open issues are an exact queue of what's left — another session or parallel agent can pick up from there without re-deriving state from the conversation.

## Command Routing Architecture

The root `justfile` routes subcommands through `direnv exec` to load the correct environment per subdirectory. **Always invoke sub-project commands through root routing**, not directly:

```bash
just ansible <recipe>   # → direnv exec ./ansible just --justfile ansible/justfile <recipe>
just images <recipe>    # → direnv exec ./images just --justfile images/justfile <recipe>
just incus <recipe>     # → direnv exec ./incus just --justfile incus/justfile <recipe>
just terraform <recipe> # → direnv exec ./terraform just --justfile terraform/justfile <recipe>
```

Running `just --list` in any subdirectory shows available recipes for that component.

## Key Commands

### Bootstrap
```bash
just bootstrap          # Install direnv
# After bootstrap: restart shell, then run 'direnv allow' in project root
just ansible install    # Set up Python venv and install all dev deps
just install-hooks      # Wire up git pre-commit hooks (run once after cloning)
```

### Ansible (run via `just ansible <recipe>`)
```bash
just ansible install        # Compile and install all Python deps (pip-compile + pip install)
just ansible reqs           # Install Ansible Galaxy requirements to galaxy_roles/
just ansible setup HOST     # Initial setup with --ask-pass (uses inventory-setup.yaml, SETUP=true)
just ansible run HOST       # Run main playbook against production host
just ansible vault edit     # Edit encrypted secrets.yaml (opens in VSCode)
just ansible vault-view     # View decrypted vault contents
just ansible vault-test     # Verify 1Password CLI can retrieve vault password
just ansible install-op-vault  # Install ~/bin/op-vault script (required for vault access)
```

### Ansible Testing
```bash
just ansible lint                      # Run ansible-lint on all roles
just ansible molecule-test             # Full test: create → converge → verify → destroy
just ansible molecule-converge         # Converge only (fast iteration, keeps container running)
just ansible molecule-verify           # Re-run verify against existing container
just ansible molecule-destroy          # Destroy test container
just ansible molecule-test ROLE=mqz-proxmox  # Target a specific role
```

### Image Building / Proxmox ISO (run via `just images <recipe>`)
```bash
just images prepare-iso        # Generate answer file from vault + embed into Proxmox ISO
just images generate-answer-file  # Generate http/auto.toml from vault only
just images status             # Show ISO and answer file status
```

### Terraform (run via `just terraform <recipe>`)

The `terraform` subsystem uses **OpenTofu** (`tofu` binary — installed via mise from `mise.toml`). All state-touching recipes (`init`/`plan`/`apply`/`destroy`) source their `TF_VAR_*` from Ansible Vault at command time via `terraform/scripts/tf-secrets.sh` — no `.tfvars`, no exports in `.envrc`. See Secret Management below.

```bash
just terraform init     # Initialize providers (run after adding/changing providers)
just terraform plan     # Show planned changes
just terraform apply    # Apply changes
just terraform destroy  # Destroy all managed resources in an environment
just terraform fmt      # Format all .tf files
just terraform validate # Validate configuration syntax
just terraform show     # Show current state
```

### Incus (optional — requires Linux dev machine with Incus installed)
```bash
just incus setup-remote         # Configure remote Incus server at 192.168.1.88:8443
just incus restore HOST clean   # Restore instance to 'clean' snapshot
just incus snapshot-timestamp HOST  # Create timestamped checkpoint
```

## Architecture

### Service Architecture

Service placement, host responsibilities, and the storage flow live in [docs/infrastructure-target-architecture.md](./docs/infrastructure-target-architecture.md). Update that doc when placement changes; do not duplicate the content here.

Implementation notes worth keeping close to operational commands:

- **Intel iGPU passthrough for Plex** — `mqz-plex` configures `/etc/pve/lxc/200.conf` on the Proxmox host to pass `/dev/dri/card0` and `/dev/dri/renderD128` into the LXC. Plex uses Intel QuickSync for 4K hardware transcoding. The `i915` driver stays loaded on the host — no blacklisting needed for LXC passthrough.
- **Caddy DNS-01 challenge** — the wildcard cert acquisition needs `cloudflare_caddy_api_token` in vault with `Zone:DNS:Edit` on `mqz.casa`.
- **Plex NFS mount** — `/mnt/media` mounts from cerebro (`192.168.1.250`) read-only.

### Ansible Testing Methodology

Molecule with Docker driver is the primary testing path. It runs roles inside a Debian container (`geerlingguy/docker-debian12-ansible`) without requiring any local Proxmox or Incus infrastructure.

- Molecule scenarios live at `ansible/roles/<role>/molecule/default/`
- `prepare.yml` — sets up the container (e.g., installs mock `pveversion`)
- `converge.yml` — applies the role with container-safe variables
- `molecule.yml` — driver config and per-host variable overrides

When adding a new role, create a molecule scenario with the same structure. Tasks that require real hardware (ZFS, kernel modules, PCIe passthrough) are disabled via variables in `converge.yml`.

### Secret Management

**Credential flow**: `ansible/group_vars/secrets.yaml` (Ansible Vault encrypted) is the single source of truth.
- `ansible.cfg` sets `vault_password_file = ~/bin/op-vault` — this script must be installed via `just ansible install-op-vault`
- `~/bin/op-vault` calls the 1Password CLI to retrieve the vault password at runtime
- Most `ansible/justfile` recipes depend on `check-op`, which supports both `op` (Linux/Mac) and `op.exe` (WSL)
- Proxmox ISO builds extract `initial_password` from vault via `images/scripts/get-vault-password.sh`
- Terraform reads `TF_VAR_*` from vault via `terraform/scripts/tf-secrets.sh` (invoked by the `_with-secrets` wrapper in `terraform/justfile`)
- Molecule CI tests define variables directly in `converge.yml` — no vault access needed in CI

**Secrets that must exist in `secrets.yaml`**:
- `initial_password` — used for Proxmox ISO unattended install and initial Ansible connection
- `tailscale_authkey` — Tailscale auth key for `mqz-tailscale` role
- `cloudflare_caddy_api_token` — Cloudflare API token for Caddy DNS-01 challenge and Terraform Cloudflare provider
- `plex_claim_token` — Plex claim token (expires in 4 minutes; get from plex.tv/claim)
- `syncthing_gui_password` — Syncthing GUI login password (mqz-cerebro role fails hard if this is missing to avoid deploying an unauthenticated GUI)

Non-secret Terraform config (Cloudflare Zone ID, endpoints, node names) lives in `terraform/environments/<env>/variables.tf` as `default = "..."`, not in vault.

### Ansible Structure

- `ansible/run.yaml` — main playbook; applies `mqz-proxmox` + `mqz-tailscale` to phoenix, `mqz-plex` to plex LXC, `mqz-caddy` to caddy LXC
- `ansible/roles/mqz-*` — custom roles prefixed with `mqz-`; external Galaxy roles install to `galaxy_roles/` (gitignored)
- `ansible/group_vars/` — per-host variable files and encrypted `secrets.yaml`
- `ansible/inventories/home-network/` — production inventory; `inventory-setup.yaml` used for initial `setup` only (SSH password auth)
- `ansible/ansible.cfg` sets `roles_path = galaxy_roles:roles:submodules`

### Terraform Structure

Terraform is organized by environment under `terraform/environments/`. The `home` environment manages:
- Proxmox VMs and LXC containers via `bpg/proxmox` provider
- Tailscale VPN config via `tailscale/tailscale` provider
- Cloudflare DNS records via `cloudflare/cloudflare` provider

Provider credentials are sourced from Ansible Vault (`ansible/group_vars/secrets.yaml`) at command time by `terraform/scripts/tf-secrets.sh`, which decrypts the vault and emits `export TF_VAR_*=...` lines for the justfile's `_with-secrets` wrapper to `eval`. This keeps a single source of truth: no `.tfvars` files, no `TF_VAR_*` exports in `.envrc`, no duplicate items in 1Password. To add a new provider credential, add its key to `secrets.yaml` (via `just ansible vault edit`) and add an `emit <tf_var> <vault_key>` line in `terraform/scripts/tf-secrets.sh`.

### Proxmox Installation (phoenix)

Phoenix requires manual Proxmox installation using a prepared ISO:
1. `just images prepare-iso` — pulls `initial_password` from vault, embeds answer file into Proxmox ISO
2. Flash `images/downloads/proxmox-ve_*-auto.iso` to USB
3. Boot phoenix from USB — installs unattended
4. Run `just ansible setup phoenix` to apply configuration

`images/http/auto.toml` is gitignored (contains vault password at runtime). Use `images/http/auto.toml.example` as reference for the answer file structure.

### CI / GitHub Actions

`.github/workflows/ci.yml` runs on every push to `main`:
- **lint** job: runs `ansible-lint roles/` — no vault access required
- **molecule** job: runs `molecule test` per role matrix — currently: `mqz-proxmox`, `mqz-tailscale`, `mqz-plex`, `mqz-caddy`

No secrets are needed in GitHub for basic lint and molecule tests.

### What Cannot Be Tested in Containers

These Ansible tasks require real Proxmox hardware and are disabled in molecule via `converge.yml` variables:
- ZFS operations (`set_zfs_arc: false`)
- PCIe/iGPU passthrough configuration (`plex_igpu_passthrough: false`)
- Kernel module loading / nested virtualization (`nested_virtualization_enable: false`)
- Proxmox web UI modifications
- NFS mounts from cerebro (replaced with local bind mounts in molecule)

## Troubleshooting

- **1Password not authenticating**: Run `just ansible check-op`; ensure `~/bin/op-vault` is installed via `just ansible install-op-vault`
- **Vault password failure**: Run `just ansible vault-test`
- **ISO credential mismatch**: Run `just images prepare-iso` to regenerate with current vault credentials
- **Molecule Docker errors**: Ensure Docker Desktop is running with WSL2 integration enabled
- **Molecule pveversion not found**: Check `prepare.yml` in the molecule scenario — it installs the mock
- **Terraform init fails**: Run `just terraform init` after any provider version change
- **Plex no hardware transcoding**: Verify `/dev/dri` devices exist on host (`ls /dev/dri`), check LXC config at `/etc/pve/lxc/200.conf`, ensure `i915` kernel module is loaded (`lsmod | grep i915`)
- **Caddy TLS errors**: Check Cloudflare API token has `Zone:DNS:Edit` permission for `mqz.casa`; verify nameservers are set to Cloudflare
- **Plex LXC IP unknown**: After `terraform apply`, check DHCP leases on your router or run `pct exec 200 -- ip addr` on phoenix to find the assigned IP, then update `inventory.yaml`
