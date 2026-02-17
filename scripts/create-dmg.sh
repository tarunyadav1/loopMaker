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

# Locate the app icon (.icns) for the DMG volume icon
APP_ICNS="$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo -e "${YELLOW}  Preparing DMG contents...${NC}"

# Copy the .app to the staging directory
cp -R "$APP_BUNDLE" "$STAGING_DIR/"

# Create Applications symlink for drag-to-install
ln -s /Applications "$STAGING_DIR/Applications"

# Remove any existing DMG
rm -f "$OUTPUT_DMG"

echo -e "${YELLOW}  Creating compressed DMG...${NC}"

# Create a temporary read-write DMG first (needed to set volume icon and Finder layout)
TEMP_DMG="$(mktemp -u).dmg"

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDRW \
    "$TEMP_DMG"

# Mount the temporary DMG to configure it
MOUNT_DIR="/Volumes/$VOLUME_NAME"

# Detach any existing volume with the same name
hdiutil detach "$MOUNT_DIR" 2>/dev/null || true

hdiutil attach "$TEMP_DMG" -mountpoint "$MOUNT_DIR" -nobrowse -quiet

# Set volume icon if the .icns exists
if [ -f "$APP_ICNS" ]; then
    echo -e "${YELLOW}  Setting volume icon...${NC}"
    cp "$APP_ICNS" "$MOUNT_DIR/.VolumeIcon.icns"
    SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns"
    SetFile -a C "$MOUNT_DIR"
fi

# Configure Finder window layout via AppleScript
APP_BASENAME="$(basename "$APP_BUNDLE")"
echo -e "${YELLOW}  Configuring DMG layout...${NC}"
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 640, 400}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set position of item "$APP_BASENAME" of container window to {140, 150}
        set position of item "Applications" of container window to {400, 150}
        close
    end tell
end tell
APPLESCRIPT

# Ensure Finder writes .DS_Store
sync
sleep 1

hdiutil detach "$MOUNT_DIR" -quiet

# Convert to compressed read-only DMG
hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$OUTPUT_DMG"

rm -f "$TEMP_DMG"

echo -e "${GREEN}  DMG created: $OUTPUT_DMG${NC}"
