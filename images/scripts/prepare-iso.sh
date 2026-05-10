#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ANSWER_FILE="$PROJECT_DIR/http/auto.toml"
OUTPUT_DIR="$PROJECT_DIR/downloads"

# ISO details
PROXMOX_ISO_URL="https://enterprise.proxmox.com/iso/proxmox-ve_9.1-1.iso"
PROXMOX_ISO_NAME="proxmox-ve_9.1-1.iso"
PREPARED_ISO_NAME="proxmox-ve_9.1-1-auto.iso"

echo -e "${BLUE}🔧 Preparing Proxmox VE ISO with automated installation...${NC}"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Download original ISO if it doesn't exist
if [[ ! -f "$OUTPUT_DIR/$PROXMOX_ISO_NAME" ]]; then
    echo -e "${YELLOW}📥 Downloading Proxmox VE ISO...${NC}"
    wget -O "$OUTPUT_DIR/$PROXMOX_ISO_NAME" "$PROXMOX_ISO_URL"
else
    echo -e "${GREEN}✅ Proxmox VE ISO already exists${NC}"
fi

# Check if answer file exists
if [[ ! -f "$ANSWER_FILE" ]]; then
    echo -e "${RED}❌ Answer file not found: $ANSWER_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}📝 Answer file: $ANSWER_FILE${NC}"

# Prepare the ISO with the answer file
echo -e "${YELLOW}🔨 Preparing ISO with embedded answer file...${NC}"

# Check if proxmox-auto-install-assistant is available
if ! command -v proxmox-auto-install-assistant &> /dev/null; then
    echo -e "${RED}❌ proxmox-auto-install-assistant not found${NC}"
    echo -e "${YELLOW}Installing proxmox-auto-install-assistant...${NC}"
    
    # Try to install it
    if command -v apt &> /dev/null; then
        # On Debian/Ubuntu systems, it might be available in the Proxmox repo
        echo -e "${YELLOW}⚠️  You may need to install proxmox-auto-install-assistant manually${NC}"
        echo -e "${BLUE}Instructions:${NC}"
        echo "1. Add Proxmox repository to your sources: echo \"deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription\" | sudo tee /etc/apt/sources.list.d/pve-install-repo.list"
        echo "2. Add Proxmox repo keys: sudo wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg"
        echo "3. Install: apt update && apt install proxmox-auto-install-assistant"
        echo "4. Or download and extract the assistant from Proxmox VE ISO"
        exit 1
    else
        echo -e "${RED}❌ Cannot install proxmox-auto-install-assistant automatically${NC}"
        exit 1
    fi
fi

# Prepare the ISO
proxmox-auto-install-assistant prepare-iso \
    "$OUTPUT_DIR/$PROXMOX_ISO_NAME" \
    --fetch-from iso \
    --answer-file "$ANSWER_FILE" \
    --output "$OUTPUT_DIR/$PREPARED_ISO_NAME"

echo -e "${GREEN}✅ Prepared ISO created: $OUTPUT_DIR/$PREPARED_ISO_NAME${NC}"
echo -e "${BLUE}💡 Flash this ISO to a USB drive for bare-metal Proxmox installation${NC}"
echo -e "${BLUE}   e.g.: sudo dd if=$OUTPUT_DIR/$PREPARED_ISO_NAME of=/dev/sdX bs=4M status=progress${NC}"