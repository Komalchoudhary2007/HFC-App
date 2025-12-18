#!/bin/bash

# HC20 SDK Switcher Script
# =========================
# This script allows easy switching between old and new SDK versions

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "========================================"
echo "   HC20 SDK Version Switcher"
echo "========================================"
echo ""

# Check current SDK
current_sdk=$(grep -A2 "hc20:" pubspec.yaml | grep "path:" | awk '{print $2}')

if [ "$current_sdk" = "./hc20" ]; then
    current_version="OLD STABLE SDK (v1.0.0)"
    new_sdk="./hc20_new"
    new_version="NEW SDK (v1.0.2)"
else
    current_version="NEW SDK (v1.0.2)"
    new_sdk="./hc20"
    new_version="OLD STABLE SDK (v1.0.0)"
fi

echo -e "${YELLOW}Current SDK:${NC} $current_version"
echo -e "${GREEN}Switch to:${NC} $new_version"
echo ""
echo "Do you want to switch? (y/n): "
read -r response

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo ""
    echo "Switching SDK..."
    
    # Create backup
    cp pubspec.yaml pubspec.yaml.backup.$(date +%Y%m%d_%H%M%S)
    echo -e "${GREEN}✓${NC} Backup created"
    
    # Switch SDK path in pubspec.yaml
    if [ "$current_sdk" = "./hc20" ]; then
        sed -i 's|path: ./hc20$|path: ./hc20_new|g' pubspec.yaml
    else
        sed -i 's|path: ./hc20_new$|path: ./hc20|g' pubspec.yaml
    fi
    echo -e "${GREEN}✓${NC} SDK path updated in pubspec.yaml"
    
    # Run flutter pub get
    echo ""
    echo "Running flutter pub get..."
    flutter pub get
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓${NC} Successfully switched to $new_version"
        echo ""
        echo "NEXT STEPS:"
        echo "1. Run: flutter clean (recommended)"
        echo "2. Run: flutter run"
        echo "3. Test all features thoroughly"
        echo ""
        echo "See SDK_TESTING_GUIDE.md for testing checklist"
    else
        echo -e "${RED}✗${NC} Error occurred during flutter pub get"
        echo "Restoring from backup..."
        mv pubspec.yaml.backup.$(date +%Y%m%d)* pubspec.yaml
        echo "Restored to previous version"
    fi
else
    echo "Cancelled. No changes made."
fi

echo ""
echo "========================================"
