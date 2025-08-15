# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a home infrastructure repository using Ansible for configuration management, Packer for image building, and supporting tools for testing and deployment. The infrastructure consists of three main machines: `phoenix` (Proxmox host), `cerebro` (services), and `dazzler` (additional services).

## Key Commands

### Main Project Commands (Root Level)
```bash
just bootstrap          # Install system dependencies (direnv, asdf)
just ansible <args>      # Route to ansible justfile commands
just incus <args>        # Route to incus justfile commands
```

### Ansible Commands (ansible/)
```bash
just install            # Compile and install all Python dependencies
just setup HOST         # Initial Proxmox setup (requires --ask-pass, uses 1Password)
just run HOST           # Run main playbook for HOST
just test HOST          # Test playbook on Incus instance
just vault ACTION       # Encrypt/decrypt/edit secrets.yaml (ACTION: encrypt/decrypt/edit)
just reqs               # Install Ansible Galaxy requirements
```

### Image Building (images/)

#### Iterative Development Workflow (RECOMMENDED)
```bash
# Step 1: Build base image once (slow, ~10 minutes)
just build-base         # Creates base Proxmox installation

# Step 2: Fast iteration on provisioning (fast, ~2 minutes)
just provision-only     # Apply Ansible provisioning to base image
just provision-debug    # Same with verbose debugging output

# Utilities
just status             # Show build status for base and final images
just clean-base         # Clean base image artifacts
just build-full         # Complete workflow: base + provision
```

#### Legacy Single-Stage Builds
```bash
just build              # Build Proxmox image with Packer (slow)
just build-and-import   # Build and import to Incus (slow)
just validate           # Validate Packer configuration
just clean              # Clean build artifacts

# Debug builds for troubleshooting
just build-debug        # Build with debug logging (PACKER_LOG=1)
just build-trace        # Build with trace logging (most verbose)
just build-log LEVEL    # Build with custom log level (DEBUG|INFO|WARN|ERROR|TRACE)
just build-and-import-debug  # Build and import with debug logging
```

### Incus Testing (incus/)
```bash
just attach HOST        # Attach to Incus instance console
just snapshot HOST NAME # Create snapshot of instance
just restore HOST NAME  # Restore instance from snapshot
```

## Architecture

### Directory Structure
- `ansible/` - Ansible playbooks and roles for configuration management
  - `roles/` - Custom roles (mqz-*) and external roles as submodules
  - `inventories/` - Inventory files for different environments (home-network, incus, vagrant)
  - `group_vars/` - Variables including encrypted secrets
- `images/` - Packer configuration for building Proxmox VM images
- `incus/` - Incus container management for testing
- `terraform/` - Terraform configuration (minimal/placeholder)
- `services/` - Docker Compose services organized by host

### Environment Management
- Uses `direnv` for environment-specific configurations
- Each subdirectory has its own `.envrc` file
- Python virtual environments managed per component
- Dependencies compiled with pip-compile

### Secret Management
- Uses 1Password CLI (`op`) for secret retrieval
- Ansible Vault for encrypted variables in `group_vars/secrets.yaml`
- VSCode configured as default editor for vault operations

### Testing Workflow
- Build Proxmox images with Packer
- Import to Incus for isolated testing
- Test Ansible playbooks against Incus instances
- Use snapshots for quick rollback during testing

### Host Mapping
| Purpose | Hostname |
|---------|----------|
| Proxmox host | `phoenix` |
| Services host | `cerebro` |
| Additional services | `dazzler` |

## Dependencies

Required tools installed via `just bootstrap`:
- `direnv` - Environment management
- `asdf` - Version management (planned)
- `just` - Command runner
- `op` (1Password CLI) - Secret management
- `packer` - Image building
- `incus` - Container/VM management
- Python with pip-compile for dependency management