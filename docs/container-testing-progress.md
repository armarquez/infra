# Container Testing Setup Progress

**Date:** 2026-02-05

## Summary

Set up container-based testing environment for Ansible playbooks on a remote Incus server. VMs are not working due to networking issues, so containers are used as an alternative.

## What's Working

### Remote Incus Server Connection
- Remote server: `192.168.1.88:8443`
- Configured in `incus/justfile` with recipes:
  - `just incus setup-remote`
  - `just incus set-remote-default`
  - `just incus set-local-default`

### Container Testing Environment
- **Instance**: `phoenix` (Debian 13/trixie container)
- **IP**: 10.0.10.183 (on incusbr0 bridge)
- **Snapshot**: `clean` for fast reset

### Mocks Installed
1. **pveversion** - Returns fake Proxmox 9.1 version info
   ```bash
   /usr/local/bin/pveversion
   # Output: pve-manager/9.1-1/1234567890abcdef (running kernel: 6.8.12-1-pve)
   ```

2. **chronyc** - Returns fake NTP data for time sync checks
   ```bash
   /usr/local/bin/chronyc ntpdata
   /usr/local/bin/chronyc tracking
   /usr/local/bin/chronyc makestep
   ```

3. **proxmoxlib.js** - Stub file for subscription popup tasks
   ```
   /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
   ```

### Configuration Files Updated
1. **ansible/inventories/incus/inventory.yaml**
   - Added `ansible_incus_remote: incus-remote` for remote connection

2. **ansible/inventories/incus/host_vars/phoenix-host.yaml**
   - `backup_etc: false` - Skip file transfer (TLS issues)

3. **CLAUDE.md**
   - Documented container testing workflow
   - Added troubleshooting section for container testing

### Packages Installed in Container
- openssh-server
- python3
- sudo
- chrony (for config files, service doesn't run)
- curl

### GPG Key
- Proxmox bookworm GPG key installed at `/etc/apt/trusted.gpg.d/proxmox-release.gpg`
- Trixie-specific key not yet published by Proxmox

## What's NOT Working

### VM Networking on Remote Incus
- VMs boot but never get DHCP IP addresses
- VM agent (vsock/9p) doesn't connect
- Affects both custom Proxmox images and official Debian cloud images
- Root cause: Server-side Incus configuration issue

### Container Limitations
- Services requiring kernel access (chrony actual sync, ZFS, etc.)
- Proxmox-specific services (pveproxy, pve-ha-*, etc.)
- PCIE passthrough testing
- Kernel module loading

## Tasks Completed in Playbook

The test run successfully completed these tasks:
1. Init (pveversion check) ✓
2. Backup etc (skipped via override) ✓
3. Timezone configuration ✓
4. NTP configuration (with mock chronyc) ✓
5. Repository preparation ✓
6. Subscription popup disable ✓

## Next Steps

1. **Fix 1Password session** - Need to run `op signin` before testing
2. **Continue playbook testing** - See how far we can get with package installation
3. **Add more mocks as needed** - For other Proxmox-specific commands
4. **Consider alternative approaches**:
   - Fix VM networking on Incus server
   - Use containerized-proxmox Docker image
   - Test directly on real Proxmox hardware

## Commands Reference

```bash
# Test workflow
just ansible test phoenix        # Run Ansible playbook
just incus restore phoenix clean # Reset to clean state

# Check status
incus list                       # List instances
incus exec phoenix -- <cmd>      # Run command in container

# Snapshot management
incus snapshot create phoenix <name>
incus snapshot restore phoenix <name>
incus snapshot delete phoenix <name>
```

## Files Changed Today

- `incus/justfile` - Added remote server configuration
- `ansible/inventories/incus/inventory.yaml` - Added remote connection setting
- `ansible/inventories/incus/host_vars/phoenix-host.yaml` - Created with overrides
- `CLAUDE.md` - Updated testing documentation
- `docs/container-testing-progress.md` - This file
