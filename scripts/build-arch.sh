#!/bin/bash
# Build script that checks for required dependencies before building

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Required packages
REQUIRED_PACKAGES=("zig" "go" "taglib" "zlib")

echo "Checking for required packages..."
echo ""

missing_packages=()

# Check each package
for package in "${REQUIRED_PACKAGES[@]}"; do
    if pacman -Qi "$package" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $package is installed"
    else
        echo -e "${RED}✗${NC} $package is NOT installed"
        missing_packages+=("$package")
    fi
done

echo ""

# If packages are missing, offer to install them
if [ ${#missing_packages[@]} -gt 0 ]; then
    echo -e "${YELLOW}Missing packages: ${missing_packages[*]}${NC}"
    echo ""
    read -p "Would you like to install the missing packages? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Installing missing packages..."
        sudo pacman -S --needed "${missing_packages[@]}"
    else
        echo -e "${RED}Error: Cannot build without required packages.${NC}"
        exit 1
    fi
fi

echo ""
echo "Building for Linux AMD64..."

# Change to project root directory (parent of scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

make linux-amd64 -j"$(nproc)"

