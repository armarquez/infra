#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if KVM is available in the kernel
check_kvm_kernel_support() {
    if [[ -r /dev/kvm ]]; then
        return 0
    elif grep -q "vmx\|svm" /proc/cpuinfo 2>/dev/null; then
        # CPU supports virtualization but /dev/kvm doesn't exist
        return 2
    else
        # No virtualization support
        return 1
    fi
}

# Function to check if user is in kvm group
check_kvm_group_membership() {
    if groups | grep -q "\bkvm\b"; then
        return 0
    else
        return 1
    fi
}

# Function to check if user can access /dev/kvm
check_kvm_access() {
    if [[ -r /dev/kvm ]] && [[ -w /dev/kvm ]]; then
        return 0
    else
        return 1
    fi
}

# Function to suggest accelerator based on environment
suggest_accelerator() {
    # Check if we're in WSL
    if grep -q -i wsl /proc/version 2>/dev/null; then
        echo "none"
        return
    fi
    
    # Check if we're in a VM (common when running in CI/container)
    if systemd-detect-virt -q 2>/dev/null; then
        echo "tcg"
        return
    fi
    
    # Check KVM availability
    if check_kvm_kernel_support && check_kvm_access; then
        echo "kvm"
        return
    fi
    
    # Fallback to software acceleration
    echo "tcg"
}

# Function to provide instructions for fixing KVM access
provide_kvm_instructions() {
    echo -e "${BLUE}To enable KVM acceleration, run the following commands:${NC}"
    echo
    echo "1. Add your user to the kvm group:"
    echo "   sudo usermod -a -G kvm \$USER"
    echo
    echo "2. Log out and log back in, or run:"
    echo "   newgrp kvm"
    echo
    echo "3. Verify access:"
    echo "   ls -la /dev/kvm"
    echo "   groups | grep kvm"
    echo
}

# Function to provide instructions for enabling KVM
provide_kvm_enable_instructions() {
    echo -e "${BLUE}To enable KVM support:${NC}"
    echo
    echo "1. Ensure virtualization is enabled in BIOS/UEFI"
    echo "2. Load KVM modules:"
    echo "   sudo modprobe kvm"
    echo "   sudo modprobe kvm_intel  # For Intel processors"
    echo "   sudo modprobe kvm_amd    # For AMD processors"
    echo
    echo "3. Install KVM packages:"
    echo "   # Ubuntu/Debian:"
    echo "   sudo apt install qemu-kvm libvirt-daemon-system"
    echo "   # RHEL/CentOS/Fedora:"
    echo "   sudo dnf install qemu-kvm libvirt"
    echo
}

# Main function
main() {
    local quiet_mode=false
    if [[ "${1:-}" == "--quiet" ]]; then
        quiet_mode=true
    fi
    
    local suggested_accelerator
    suggested_accelerator=$(suggest_accelerator)
    
    # Check KVM kernel support
    local kvm_kernel_status
    check_kvm_kernel_support
    kvm_kernel_status=$?
    
    if [[ "$quiet_mode" == false ]]; then
        echo "🔍 Checking KVM availability..."
        echo
    fi
    
    case $kvm_kernel_status in
        0)
            if [[ "$quiet_mode" == false ]]; then
                echo -e "${GREEN}✓${NC} KVM kernel support is available"
            fi
            
            # Check user access
            if check_kvm_access; then
                if [[ "$quiet_mode" == false ]]; then
                    echo -e "${GREEN}✓${NC} User has KVM access"
                    echo -e "${GREEN}✅ KVM acceleration is available${NC}"
                fi
                export QEMU_ACCELERATOR="kvm"
            else
                if [[ "$quiet_mode" == false ]]; then
                    echo -e "${RED}✗${NC} User does not have KVM access"
                    
                    if ! check_kvm_group_membership; then
                        echo -e "${YELLOW}!${NC} User is not in kvm group"
                        provide_kvm_instructions
                    fi
                fi
                export QEMU_ACCELERATOR="$suggested_accelerator"
            fi
            ;;
        1)
            if [[ "$quiet_mode" == false ]]; then
                echo -e "${RED}✗${NC} No virtualization support detected in CPU"
                echo -e "${YELLOW}!${NC} Using software acceleration (slower)"
                provide_kvm_enable_instructions
            fi
            export QEMU_ACCELERATOR="$suggested_accelerator"
            ;;
        2)
            if [[ "$quiet_mode" == false ]]; then
                echo -e "${YELLOW}!${NC} CPU supports virtualization but KVM is not loaded"
                echo -e "${YELLOW}!${NC} Using software acceleration (slower)"
                provide_kvm_enable_instructions
            fi
            export QEMU_ACCELERATOR="$suggested_accelerator"
            ;;
    esac
    
    if [[ "$quiet_mode" == false ]]; then
        echo
        echo "Recommended QEMU accelerator: $QEMU_ACCELERATOR"
        
        if [[ "$QEMU_ACCELERATOR" != "kvm" ]]; then
            echo -e "${YELLOW}⚠️  Using non-KVM acceleration will be significantly slower${NC}"
        fi
    fi
    
    # Export for use by other scripts
    echo "export QEMU_ACCELERATOR='$QEMU_ACCELERATOR'"
}

# Run main function
main "$@"