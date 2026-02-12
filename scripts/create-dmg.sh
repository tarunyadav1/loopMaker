#!/bin/bash
set -e

# =============================================================================
# LoopMaker - DMG Creation Script
# Creates a distributable DMG with drag-to-Applications layout.
# =============================================================================

# Usage: ./scripts/create-dmg.sh <app-bundle-path> <output-dmg-path> <volume-name>

APP_BUNDLE="${1:?Error: app bundle path required (e.g. build/LoopMaker.app)}"
OUTPUT_DMG="${2:?Error: output DMG path required (e.g. build/LoopMaker-1.0.0.dmg)}"
VOLUME_NAME="${3:-LoopMaker}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Validate inputs
if [ ! -d "$APP_BUNDLE" ]; then
    echo -e "${RED}Error: App bundle not found at $APP_BUNDLE${NC}"
    exit 1
fi

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

echo -e "${YELLOW}  Preparing DMG contents...${NC}"

# Copy the .app to the staging directory
cp -R "$APP_BUNDLE" "$STAGING_DIR/"

# Create Applications symlink for drag-to-install
ln -s /Applications "$STAGING_DIR/Applications"

# Remove any existing DMG
rm -f "$OUTPUT_DMG"

echo -e "${YELLOW}  Creating compressed DMG...${NC}"

# Create the DMG
# UDZO = compressed (zlib), good balance of size and compatibility
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$OUTPUT_DMG"

echo -e "${GREEN}  DMG created: $OUTPUT_DMG${NC}"
