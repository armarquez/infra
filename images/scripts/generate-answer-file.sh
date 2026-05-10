#!/usr/bin/env bash
set -euo pipefail

# Generate Proxmox answer file with password from Ansible vault
# This ensures the automated installation uses the same password as Ansible testing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ANSWER_FILE_TEMPLATE="$PROJECT_DIR/http/auto.toml.template"
ANSWER_FILE="$PROJECT_DIR/http/auto.toml"

# Get password from vault
echo "🔐 Extracting password from Ansible vault..."
PASSWORD=$("${SCRIPT_DIR}/get-vault-password.sh")
if [[ -z "${PASSWORD}" ]]; then
    echo "❌ Failed to get password from vault"
    exit 1
fi

# Create answer file from template
echo "📝 Generating answer file with vault password..."
cat > "${ANSWER_FILE}" << EOF
# Proxmox VE Automated Installation Answer File
# Reference: https://pve.proxmox.com/wiki/Automated_Installation#Answer_File_Format_2

[global]
keyboard = "en-us"
country = "us"
timezone = "UTC"
fqdn = "proxmox-template.local"
mailto = "admin@example.com"
root_password = "${PASSWORD}"

[network]
source = "from-dhcp"

[disk-setup]
disk_list = ["vda"]
filesystem = "ext4"
EOF

echo "✅ Answer file generated: ${ANSWER_FILE}"
echo "🔑 Using password from Ansible vault"
