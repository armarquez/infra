#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../output"
IMAGE_NAME="proxmox-ve-8.2-incus.qcow2"
INCUS_IMAGE_NAME="proxmox-ve-8.2-incus"

# Check if the built image exists
if [ ! -f "${OUTPUT_DIR}/${IMAGE_NAME}" ]; then
    echo "Error: Built image ${OUTPUT_DIR}/${IMAGE_NAME} not found!"
    echo "Please run 'just build' first to create the image."
    exit 1
fi

echo "Converting ${IMAGE_NAME} to Incus format..."

# Create metadata.yaml for the image
cat > "${OUTPUT_DIR}/metadata.yaml" << EOF
architecture: x86_64
creation_date: $(date -u +%s)
properties:
  description: "Proxmox VE 8.2 for Incus"
  os: "proxmox"
  release: "8.2"
  variant: "default"
templates:
  /etc/hostname:
    when:
      - create
      - copy
    template: hostname.tpl
  /etc/hosts:
    when:
      - create
      - copy
    template: hosts.tpl
  /etc/machine-id:
    when:
      - create
      - copy
    create_only: true
    template: machine-id.tpl
EOF

# Create template files
mkdir -p "${OUTPUT_DIR}/templates"

cat > "${OUTPUT_DIR}/templates/hostname.tpl" << 'EOF'
{{ container.name }}
EOF

cat > "${OUTPUT_DIR}/templates/hosts.tpl" << 'EOF'
127.0.0.1   localhost
127.0.1.1   {{ container.name }}

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

cat > "${OUTPUT_DIR}/templates/machine-id.tpl" << 'EOF'
{{ uuid.default }}
EOF

# Import the image to Incus
echo "Importing image to Incus..."
incus image import "${OUTPUT_DIR}/${IMAGE_NAME}" "${OUTPUT_DIR}/metadata.yaml" --alias "${INCUS_IMAGE_NAME}"

echo "✅ Image successfully imported to Incus with alias: ${INCUS_IMAGE_NAME}"
echo "You can now create an instance with: incus launch ${INCUS_IMAGE_NAME} my-proxmox"

# Clean up temporary files
rm -f "${OUTPUT_DIR}/metadata.yaml"
rm -rf "${OUTPUT_DIR}/templates"

echo "🧹 Cleaned up temporary files"