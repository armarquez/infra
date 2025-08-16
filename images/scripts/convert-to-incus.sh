#!/usr/bin/env bash
set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../output"
IMAGE_NAME="proxmox-ve-9.0-incus.qcow2"
INCUS_IMAGE_NAME="proxmox-ve-9.0-incus"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cleanup function for trap
cleanup() {
    if [ -n "${TEMP_DIR:-}" ] && [ -d "${TEMP_DIR}" ]; then
        echo -e "${YELLOW}⚠️  Cleaning up temporary files due to interruption...${NC}"
        rm -rf "${TEMP_DIR}"
    fi
    if [ -n "${UNIFIED_IMAGE:-}" ] && [ -f "${UNIFIED_IMAGE}" ]; then
        rm -f "${UNIFIED_IMAGE}"
    fi
}

# Set trap for cleanup on exit/interrupt
trap cleanup EXIT INT TERM

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  ${1}${NC}"
}

log_success() {
    echo -e "${GREEN}✅ ${1}${NC}"
}

log_error() {
    echo -e "${RED}❌ ${1}${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠️  ${1}${NC}"
}

# Check if the built image exists
if [ ! -f "${OUTPUT_DIR}/${IMAGE_NAME}" ]; then
    log_error "Built image ${OUTPUT_DIR}/${IMAGE_NAME} not found!"
    log_info "Please run 'just build' first to create the image."
    exit 1
fi

log_info "Creating unified Incus image format..."

# Create temporary directory for unified image
TEMP_DIR="${OUTPUT_DIR}/incus-unified-image"
if [ -d "${TEMP_DIR}" ]; then
    log_warning "Removing existing temporary directory..."
    rm -rf "${TEMP_DIR}"
fi
mkdir -p "${TEMP_DIR}"

# Create metadata.yaml for VM image
cat > "${TEMP_DIR}/metadata.yaml" << EOF
architecture: x86_64
creation_date: $(date -u +%s)
type: virtual-machine
properties:
  description: "Proxmox VE 9.0 for Incus"
  os: "proxmox"
  release: "9.0"
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

# Copy the QCOW2 image as rootfs.img
log_info "Copying VM disk image (this may take a moment)..."
cp "${OUTPUT_DIR}/${IMAGE_NAME}" "${TEMP_DIR}/rootfs.img"

# Create template files
mkdir -p "${TEMP_DIR}/templates"

cat > "${TEMP_DIR}/templates/hostname.tpl" << 'EOF'
{{ instance.name }}
EOF

cat > "${TEMP_DIR}/templates/hosts.tpl" << 'EOF'
127.0.0.1   localhost
127.0.1.1   {{ instance.name }}

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

cat > "${TEMP_DIR}/templates/machine-id.tpl" << 'EOF'
{{ uuid.default }}
EOF

# Create unified image tarball (uncompressed for speed)
log_info "Creating unified image tarball..."
UNIFIED_IMAGE="${OUTPUT_DIR}/${INCUS_IMAGE_NAME}.tar"

# Remove existing tarball if present
if [ -f "${UNIFIED_IMAGE}" ]; then
    log_warning "Removing existing tarball..."
    rm -f "${UNIFIED_IMAGE}"
fi

cd "${TEMP_DIR}"
tar -cf "${UNIFIED_IMAGE}" metadata.yaml rootfs.img templates/
cd - > /dev/null

log_success "Tarball created: $(du -h "${UNIFIED_IMAGE}" | cut -f1)"

# Check if Incus is available
if ! command -v incus >/dev/null 2>&1; then
    log_error "Incus command not found. Please install Incus first."
    exit 1
fi

# Check if we can connect to Incus server
if ! incus info >/dev/null 2>&1; then
    log_error "Cannot connect to Incus server. Please check your Incus configuration."
    exit 1
fi

# Check if image already exists and remove it
if incus image list | grep -q "${INCUS_IMAGE_NAME}"; then
    log_warning "Image '${INCUS_IMAGE_NAME}' already exists. Removing..."
    if ! incus image delete "${INCUS_IMAGE_NAME}"; then
        log_error "Failed to remove existing image"
        exit 1
    fi
fi

# Import the unified image to Incus
log_info "Importing unified image to Incus (this may take several minutes for large images)..."
log_info "Progress: Uploading $(du -h "${UNIFIED_IMAGE}" | cut -f1) image file..."

if incus image import "${UNIFIED_IMAGE}" --alias "${INCUS_IMAGE_NAME}" 2>/dev/null; then
    log_success "Image successfully imported to Incus with alias: ${INCUS_IMAGE_NAME}"
    log_info "You can now create a VM instance with:"
    echo "  incus launch ${INCUS_IMAGE_NAME} my-proxmox --vm"
    echo "  incus launch ${INCUS_IMAGE_NAME} my-proxmox --vm -c limits.cpu=2 -c limits.memory=4GB"
else
    log_error "Failed to import image to Incus"
    log_info "This might be due to:"
    log_info "  - Network connectivity issues"
    log_info "  - Insufficient disk space on Incus server"
    log_info "  - Image format compatibility issues"
    log_info "  - Incus server permissions"
    exit 1
fi

# Clean up temporary files
log_info "Cleaning up temporary files..."
rm -rf "${TEMP_DIR}"
rm -f "${UNIFIED_IMAGE}"

log_success "Import completed successfully! 🎉"