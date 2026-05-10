#!/usr/bin/env bash
set -euo pipefail

# Get the initial password from Ansible vault for image provisioning
# This ensures the image is built with the same password Ansible testing expects

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="${SCRIPT_DIR}/../../ansible"

if [[ ! -f "${ANSIBLE_DIR}/group_vars/secrets.yaml" ]]; then
    echo "❌ Error: Ansible vault file not found at ${ANSIBLE_DIR}/group_vars/secrets.yaml" >&2
    exit 1
fi

# Extract initial_password from the vault
cd "${ANSIBLE_DIR}"
INITIAL_PASSWORD=$(ansible-vault view group_vars/secrets.yaml | grep "initial_password:" | cut -d' ' -f2)

if [[ -z "${INITIAL_PASSWORD}" ]]; then
    echo "❌ Error: Could not extract initial_password from vault" >&2
    exit 1
fi

echo "${INITIAL_PASSWORD}"
