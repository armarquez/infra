#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to install packages based on package manager
install_packages() {
    local packages=("$@")
    local pkg_manager="$PACKAGE_MANAGER"
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        echo -e "${GREEN}✅ No packages to install${NC}"
        return 0
    fi
    
    echo -e "${BLUE}📦 Installing packages: ${packages[*]}${NC}"
    
    case "$pkg_manager" in
        "apt")
            # Add HashiCorp repository for Packer if needed
            if [[ " ${packages[*]} " =~ " packer " ]]; then
                echo -e "${YELLOW}🔑 Adding HashiCorp repository...${NC}"
                if ! [ -f /usr/share/keyrings/hashicorp-archive-keyring.gpg ]; then
                    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
                    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
                    sudo apt update
                fi
            fi
            
            # Add Incus repository if needed
            if [[ " ${packages[*]} " =~ " incus " ]]; then
                echo -e "${YELLOW}🔑 Adding Incus repository...${NC}"
                if ! [ -f /etc/apt/sources.list.d/zabbly-incus-stable.sources ]; then
                    sudo mkdir -p /etc/apt/keyrings/
                    sudo curl -fsSL https://pkgs.zabbly.com/key.asc -o /etc/apt/keyrings/zabbly.asc
                    sudo sh -c 'cat <<EOF > /etc/apt/sources.list.d/zabbly-incus-stable.sources
Enabled: yes
Types: deb
URIs: https://pkgs.zabbly.com/incus/stable
Suites: $(. /etc/os-release && echo ${VERSION_CODENAME})
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/zabbly.asc

EOF'
                    sudo apt update
                fi
            fi
            
            sudo apt install -y "${packages[@]}"
            ;;
        "yum")
            # Add EPEL for additional packages
            sudo yum install -y epel-release
            sudo yum install -y "${packages[@]}"
            ;;
        "dnf")
            sudo dnf install -y "${packages[@]}"
            ;;
        "pacman")
            sudo pacman -S --noconfirm "${packages[@]}"
            ;;
        *)
            echo -e "${RED}❌ Unsupported package manager: $pkg_manager${NC}" >&2
            echo "Please install the following packages manually: ${packages[*]}" >&2
            exit 1
            ;;
    esac
}

# Function to install optional packages with user confirmation
install_optional_packages() {
    local packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi
    
    echo -e "${YELLOW}📋 Optional packages available: ${packages[*]}${NC}"
    read -p "Install optional packages? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_packages "${packages[@]}"
    else
        echo -e "${YELLOW}⏭️  Skipping optional packages${NC}"
    fi
}

echo -e "${BLUE}🔍 Checking dependencies...${NC}"

# Run check-deps.sh to get missing packages, but don't fail if it returns error
set +e
source ./scripts/check-deps.sh --quiet
CHECK_RESULT=$?
set -e

# If check-deps.sh didn't export the variables, we need to run it differently
if [[ -z "${MISSING_REQUIRED:-}" ]]; then
    echo -e "${YELLOW}⚠️  Re-running dependency check...${NC}"
    
    # Source the check script to get the exported variables
    TEMP_OUTPUT=$(mktemp)
    ./scripts/check-deps.sh --quiet > "$TEMP_OUTPUT" 2>&1 || true
    
    # Parse the output to determine what's missing
    if command -v packer &> /dev/null; then
        PACKER_MISSING=""
    else
        PACKER_MISSING="packer"
    fi
    
    if command -v ansible-playbook &> /dev/null; then
        ANSIBLE_MISSING=""
    else
        ANSIBLE_MISSING="ansible"
    fi
    
    if command -v qemu-system-x86_64 &> /dev/null; then
        QEMU_MISSING=""
    else
        QEMU_MISSING="qemu-kvm"
    fi
    
    if command -v incus &> /dev/null; then
        INCUS_MISSING=""
    else
        INCUS_MISSING="incus"
    fi
    
    if command -v just &> /dev/null; then
        JUST_MISSING=""
    else
        JUST_MISSING="just"
    fi
    
    # Determine package manager
    if command -v apt &> /dev/null; then
        PACKAGE_MANAGER="apt"
    elif command -v yum &> /dev/null; then
        PACKAGE_MANAGER="yum"
    elif command -v dnf &> /dev/null; then
        PACKAGE_MANAGER="dnf"
    elif command -v pacman &> /dev/null; then
        PACKAGE_MANAGER="pacman"
    else
        PACKAGE_MANAGER="unknown"
    fi
    
    # Build arrays of missing packages
    missing_required_packages=()
    missing_optional_packages=()
    
    [[ -n "$PACKER_MISSING" ]] && missing_required_packages+=("$PACKER_MISSING")
    [[ -n "$ANSIBLE_MISSING" ]] && missing_required_packages+=("$ANSIBLE_MISSING")
    [[ -n "$QEMU_MISSING" ]] && missing_required_packages+=("$QEMU_MISSING")
    [[ -n "$INCUS_MISSING" ]] && missing_required_packages+=("$INCUS_MISSING")
    [[ -n "$JUST_MISSING" ]] && missing_optional_packages+=("$JUST_MISSING")
    
    rm -f "$TEMP_OUTPUT"
else
    # Convert space-separated strings to arrays
    read -ra missing_required_cmds <<< "$MISSING_REQUIRED"
    read -ra missing_optional_cmds <<< "$MISSING_OPTIONAL"
    
    # Map commands to packages
    declare -A cmd_to_package=(
        ["packer"]="packer"
        ["ansible-playbook"]="ansible"
        ["qemu-system-x86_64"]="qemu-kvm"
        ["incus"]="incus"
        ["just"]="just"
    )
    
    missing_required_packages=()
    missing_optional_packages=()
    
    for cmd in "${missing_required_cmds[@]}"; do
        [[ -n "$cmd" ]] && missing_required_packages+=("${cmd_to_package[$cmd]}")
    done
    
    for cmd in "${missing_optional_cmds[@]}"; do
        [[ -n "$cmd" ]] && missing_optional_packages+=("${cmd_to_package[$cmd]}")
    done
fi

# Install required packages
if [[ ${#missing_required_packages[@]} -gt 0 ]]; then
    echo -e "${RED}🔧 Installing required packages...${NC}"
    install_packages "${missing_required_packages[@]}"
    echo -e "${GREEN}✅ Required packages installed successfully!${NC}"
else
    echo -e "${GREEN}✅ All required packages are already installed!${NC}"
fi

# Install optional packages (with user confirmation)
if [[ ${#missing_optional_packages[@]} -gt 0 ]]; then
    install_optional_packages "${missing_optional_packages[@]}"
fi

echo -e "${BLUE}🔍 Running final dependency check...${NC}"
if ./scripts/check-deps.sh; then
    echo -e "${GREEN}🎉 All dependencies are now properly installed!${NC}"
else
    echo -e "${RED}❌ Some dependencies are still missing. Please check the output above.${NC}"
    exit 1
fi