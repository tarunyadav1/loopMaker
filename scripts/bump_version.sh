#!/bin/bash
set -e

# =============================================================================
# LoopMaker - Version Bump Script
# =============================================================================

BUMP_TYPE=${1:-patch}
INFO_PLIST="LoopMaker/Info.plist"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Get current version
if [ -f "$INFO_PLIST" ]; then
    CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "1.0.0")
else
    CURRENT_VERSION="1.0.0"
fi

# Parse version
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Bump version based on type
case $BUMP_TYPE in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
    *)
        echo -e "${YELLOW}Usage: $0 [major|minor|patch]${NC}"
        exit 1
        ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

echo -e "${YELLOW}Bumping version: ${CURRENT_VERSION} -> ${NEW_VERSION}${NC}"

# Update Info.plist if it exists
if [ -f "$INFO_PLIST" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "$INFO_PLIST"

    # Increment build number
    BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "0")
    NEW_BUILD=$((BUILD_NUMBER + 1))
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$INFO_PLIST"

    echo -e "${GREEN}Updated Info.plist:${NC}"
    echo -e "  Version: ${NEW_VERSION}"
    echo -e "  Build: ${NEW_BUILD}"
else
    echo -e "${YELLOW}No Info.plist found. Version: ${NEW_VERSION}${NC}"
fi

echo -e "${GREEN}Version bump complete!${NC}"
