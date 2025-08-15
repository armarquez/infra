#!/usr/bin/env bash
set -euo pipefail

# Define dependencies with their package names and check commands
declare -A DEPENDENCIES=(
    ["packer"]="packer"
    ["ansible-playbook"]="ansible"
    ["qemu-system-x86_64"]="qemu-kvm"
    ["incus"]="incus"
)

# Optional dependencies (won't cause failure but will be reported)
declare -A OPTIONAL_DEPS=(
    ["just"]="just"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a command exists
check_command() {
    command -v "$1" &> /dev/null
}

# Function to get package manager
get_package_manager() {
    if command -v apt &> /dev/null; then
        echo "apt"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

# Check if running in quiet mode
QUIET_MODE=false
if [[ "${1:-}" == "--quiet" ]]; then
    QUIET_MODE=true
fi

# Arrays to track missing dependencies
missing_required=()
missing_optional=()

# Check required dependencies
for cmd in "${!DEPENDENCIES[@]}"; do
    if check_command "$cmd"; then
        [[ "$QUIET_MODE" == false ]] && echo -e "${GREEN}✓${NC} $cmd is installed"
    else
        missing_required+=("$cmd")
        [[ "$QUIET_MODE" == false ]] && echo -e "${RED}✗${NC} $cmd is missing (package: ${DEPENDENCIES[$cmd]})"
    fi
done

# Check optional dependencies
for cmd in "${!OPTIONAL_DEPS[@]}"; do
    if check_command "$cmd"; then
        [[ "$QUIET_MODE" == false ]] && echo -e "${GREEN}✓${NC} $cmd is installed (optional)"
    else
        missing_optional+=("$cmd")
        [[ "$QUIET_MODE" == false ]] && echo -e "${YELLOW}!${NC} $cmd is missing (optional: ${OPTIONAL_DEPS[$cmd]})"
    fi
done

# Check KVM availability and set accelerator
if [[ "$QUIET_MODE" == false ]]; then
    echo
    ./scripts/check-kvm.sh
else
    ./scripts/check-kvm.sh --quiet
fi

# Source the accelerator setting
eval "$(./scripts/check-kvm.sh --quiet)"

# Export missing dependencies for use by install script
export MISSING_REQUIRED="${missing_required[*]}"
export MISSING_OPTIONAL="${missing_optional[*]}"
export PACKAGE_MANAGER=$(get_package_manager)

# Report results
if [[ ${#missing_required[@]} -eq 0 ]]; then
    [[ "$QUIET_MODE" == false ]] && echo -e "\n${GREEN}✅ All required dependencies are installed!${NC}"
    exit 0
else
    [[ "$QUIET_MODE" == false ]] && echo -e "\n${RED}❌ Missing ${#missing_required[@]} required dependencies${NC}"
    [[ "$QUIET_MODE" == false ]] && echo "You can install them with: just install-deps"
    exit 1
fi