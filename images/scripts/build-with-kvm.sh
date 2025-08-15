#!/usr/bin/env bash
set -euo pipefail

# Source the KVM check to get QEMU_ACCELERATOR
eval "$(./scripts/check-kvm.sh --quiet)"

# Check if debug mode is enabled
if [[ "${PACKER_DEBUG:-}" == "1" ]] || [[ "${PACKER_LOG:-}" != "" ]]; then
    echo "🐛 Debug mode enabled"
    echo "Using QEMU accelerator: ${QEMU_ACCELERATOR}"
    if [[ "${PACKER_LOG:-}" != "" ]]; then
        echo "Packer log level: ${PACKER_LOG}"
    fi
else
    echo "Using QEMU accelerator: ${QEMU_ACCELERATOR}"
fi

packer build "$@" -var "qemu_accelerator=${QEMU_ACCELERATOR}" .