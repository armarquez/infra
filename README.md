# armarquez/infra

This repo implements Infrastructure as Code (IaC) for home infrastructure deployment using:
- **Ansible** for configuration management and system provisioning
- **Packer** for automated VM image building with Proxmox VE
- **Incus** for containerized testing and development environments
- **Just** as a command runner for orchestrating complex workflows

The infrastructure supports three main physical machines:

| Purpose | Hostname |
|---------|----------|
| Proxmox hypervisor host | `phoenix` |
| Services host | `cerebro` |
| Additional services host | `dazzler` |

*Heavily based upon: https://github.com/ironicbadger/infra*

## Quick Start

```bash
# Install system dependencies
just bootstrap

# Build and deploy test environment (one-time setup)
just images build-base                    # Build base Proxmox image (~10 min)
just images provision-only               # Apply Ansible provisioning (~2 min)
just images import-to-incus              # Deploy to Incus for testing
just images recreate-instance phoenix    # Create fresh instance with clean snapshot

# Fast iteration testing loop
just ansible test phoenix                # Test Ansible playbooks
just incus restore phoenix clean         # Reset to pristine state
# Modify playbooks and repeat...

# Or use the automated workflow
just test-workflow phoenix              # Complete: restore + test
```

## Key Innovation: Unified Credential Management

The project implements a sophisticated credential synchronization system that ensures image building and Ansible testing use the same passwords from a single source of truth (Ansible Vault), eliminating credential drift and authentication failures.

**Credential Flow:**
1. All passwords stored in encrypted `ansible/group_vars/secrets.yaml`
2. Image building scripts automatically extract credentials from vault
3. Packer builds use vault-sourced credentials
4. Ansible testing uses identical vault credentials
5. **Result:** Perfect synchronization between image building and testing

## Architecture Overview

The workflow enables safe infrastructure development without affecting production hosts:

1. **Image Building** - Packer creates Proxmox VM images with vault credentials
2. **Testing Environment** - Images deployed to Incus for isolated testing
3. **Snapshot-Based Testing** - Quick rollback enables fast iteration cycles
4. **Production Deployment** - Tested playbooks applied to actual hosts

## Component Overview

### Image Building (`images/`)
- **Iterative Development**: Build base once (`just build-base`), fast provision iterations (`just provision-only`)
- **Credential Integration**: Automatic vault password extraction and answer file generation
- **Instance Management**: Launch, snapshot, and manage Incus instances
- **Debug Support**: Multiple debugging levels and verbose output options

### Ansible Automation (`ansible/`)
- **Testing**: `just test HOST` - Test against Incus instances
- **Production**: `just run HOST` - Deploy to production hosts
- **Iteration Support**: `just test-clean HOST` - Reset and test in one command
- **Vault Management**: Encrypted credential storage with 1Password integration

### Incus Testing (`incus/`)
- **Snapshot Management**: Create, restore, and list snapshots for rollback testing
- **Console Access**: Direct VGA console access for debugging
- **Instance Lifecycle**: Automated starting, stopping, and health checking

## Key Benefits

- **Credential Synchronization**: Eliminates password drift between image building and testing
- **Risk-Free Testing**: Experiment with destructive changes safely in isolated VMs
- **Fast Iteration**: VM snapshots enable instant rollback (~10 seconds vs ~10 minutes rebuild)
- **Consistent Baseline**: Always start testing from known-good state
- **Professional Workflow**: CI/CD-like infrastructure development process

## Dependencies & Setup

### Quick Bootstrap
```bash
just bootstrap     # Installs direnv and core dependencies
```

### Core Tools
- **`just`** - Command runner and workflow orchestration
- **`direnv`** - Environment management and variable loading
- **`packer`** - Automated VM image building
- **`incus`** - Container and VM management for testing
- **`ansible`** - Configuration management and provisioning
- **`op` (1Password CLI)** - External secret management integration

### Advanced Setup (if needed)
For manual Incus configuration or troubleshooting:
1. Follow [Incus Getting Started docs](https://linuxcontainers.org/incus/docs/main/tutorial/first_steps/)
2. Ensure Docker is not installed (can interfere with networking)
3. Configure bridge networking if required for your environment

## Quick Reference

### Most Common Commands
```bash
# Development workflow
just images build-base && just images provision-only
just images recreate-instance phoenix
just test-workflow phoenix

# Troubleshooting
just images status
just images help
just ansible vault-view
```

## Documentation

- **CLAUDE.md** - Complete command reference and architecture guide
- **images/README.md** - Packer image building details
- **incus/README.md** - Incus instance and snapshot management
- **GEMINI.md** - Gemini-specific guidance (auto-generated)