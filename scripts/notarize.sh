#!/bin/bash
set -e

# =============================================================================
# LoopMaker - Notarization Script
# Submits a signed .app, .dmg, or .zip to Apple for notarization.
# =============================================================================

# Usage: ./scripts/notarize.sh <path-to-dmg-or-app>

ARTIFACT="${1:?Error: path to .dmg or .app required}"

APP_NAME="LoopMaker"
BUNDLE_ID="com.loopmaker.LoopMaker"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Notarizing ${APP_NAME}...${NC}"

# Check for required environment variables
if [ -z "$APPLE_ID" ]; then
    echo -e "${RED}Error: APPLE_ID environment variable not set${NC}"
    echo -e "${YELLOW}Export your Apple ID email: export APPLE_ID=you@example.com${NC}"
    exit 1
fi

if [ -z "$APP_SPECIFIC_PASSWORD" ]; then
    echo -e "${RED}Error: APP_SPECIFIC_PASSWORD environment variable not set${NC}"
    echo -e "${YELLOW}Generate one at https://appleid.apple.com/account/manage${NC}"
    exit 1
fi

if [ -z "$TEAM_ID" ]; then
    echo -e "${RED}Error: TEAM_ID environment variable not set${NC}"
    echo -e "${YELLOW}Find your Team ID at https://developer.apple.com/account${NC}"
    exit 1
fi

# Validate artifact exists
if [ ! -e "$ARTIFACT" ]; then
    echo -e "${RED}Error: $ARTIFACT not found${NC}"
    exit 1
fi

# Determine what we're notarizing
SUBMIT_PATH="$ARTIFACT"

if [ -d "$ARTIFACT" ] && [[ "$ARTIFACT" == *.app ]]; then
    # It's an .app bundle — zip it for submission
    echo -e "${YELLOW}  Zipping .app for notarization submission...${NC}"
    ZIP_PATH="${ARTIFACT%.app}.zip"
    ditto -c -k --keepParent "$ARTIFACT" "$ZIP_PATH"
    SUBMIT_PATH="$ZIP_PATH"
    CLEANUP_ZIP=true
elif [ -f "$ARTIFACT" ] && [[ "$ARTIFACT" == *.dmg ]]; then
    # It's a DMG — submit directly
    SUBMIT_PATH="$ARTIFACT"
    CLEANUP_ZIP=false
else
    echo -e "${RED}Error: $ARTIFACT must be a .app directory or .dmg file${NC}"
    exit 1
fi

# Submit for notarization
echo -e "${YELLOW}  Submitting to Apple for notarization...${NC}"
xcrun notarytool submit "$SUBMIT_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait

# Clean up temporary zip
if [ "$CLEANUP_ZIP" = true ] && [ -f "$ZIP_PATH" ]; then
    rm -f "$ZIP_PATH"
fi

# Staple the notarization ticket
echo -e "${YELLOW}  Stapling notarization ticket...${NC}"
if [[ "$ARTIFACT" == *.dmg ]]; then
    xcrun stapler staple "$ARTIFACT"
elif [[ "$ARTIFACT" == *.app ]]; then
    xcrun stapler staple "$ARTIFACT"
fi

echo -e "${GREEN}Notarization complete!${NC}"
echo -e "${GREEN}  Artifact: $ARTIFACT${NC}"
