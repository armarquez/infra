# Windows

Bootstrap scripts for Windows machines on the LAN. Parallel to `ansible/`, `terraform/`, `incus/` — one top-level dir per tool/domain.

Currently only one machine (`forge`, the daily-driver laptop). If additional Windows machines join later, the scripts here are meant to be reusable for them.

## Scripts

- **`scripts/setup-syncthing.ps1`** — installs Syncthing via winget, registers a scheduled task that runs it at login (with restart-on-crash and battery-safe), and prints the device ID for pairing with cerebro. Idempotent — safe to re-run.
  ```powershell
  pwsh windows/scripts/setup-syncthing.ps1
  ```

## Why PowerShell, not Ansible

Ansible against Windows works but requires either WinRM configuration or an OpenSSH server on the Windows host, plus `pywinrm` on the control machine. For a solo Windows laptop, that's more machinery than the tasks warrant — a self-contained, checked-in PowerShell script is easier to read, run, and reason about.

If we ever need to manage multiple Windows machines with meaningful shared configuration (registry policies, per-user profiles, etc.), migrating to Ansible is straightforward: each script here already documents a single unit of state that would map cleanly to a role's tasks.
