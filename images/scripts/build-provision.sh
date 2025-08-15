#!/usr/bin/env bash
set -euo pipefail

# Source the KVM check to get QEMU_ACCELERATOR
eval "$(./scripts/check-kvm.sh --quiet)"

echo "Using QEMU accelerator: ${QEMU_ACCELERATOR}"
packer build "$@" -var "qemu_accelerator=${QEMU_ACCELERATOR}" proxmox-ve-provision.pkr.hcl