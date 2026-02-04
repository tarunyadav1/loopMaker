#!/bin/bash
set -e

# =============================================================================
# LoopMaker - Notarization Script
# =============================================================================

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
    exit 1
fi

if [ -z "$APP_SPECIFIC_PASSWORD" ]; then
    echo -e "${RED}Error: APP_SPECIFIC_PASSWORD environment variable not set${NC}"
    exit 1
fi

if [ -z "$TEAM_ID" ]; then
    echo -e "${RED}Error: TEAM_ID environment variable not set${NC}"
    exit 1
fi

# Check if binary exists
if [ ! -f "build/Release/${APP_NAME}" ]; then
    echo -e "${RED}Error: build/Release/${APP_NAME} not found${NC}"
    echo -e "${YELLOW}Run 'make archive' first${NC}"
    exit 1
fi

# Create zip for notarization
echo -e "${YELLOW}Creating zip archive...${NC}"
cd build/Release
zip -r "${APP_NAME}.zip" "${APP_NAME}"

# Submit for notarization
echo -e "${YELLOW}Submitting to Apple for notarization...${NC}"
xcrun notarytool submit "${APP_NAME}.zip" \
    --apple-id "$APPLE_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait

echo -e "${GREEN}Notarization complete!${NC}"
