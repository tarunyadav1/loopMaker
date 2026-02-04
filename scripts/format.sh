#!/bin/bash
set -e

# =============================================================================
# LoopMaker - Format & Lint Script
# =============================================================================

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${GREEN}Formatting code...${NC}"

# Run SwiftFormat
if command -v swiftformat &> /dev/null; then
    swiftformat . --quiet
    echo -e "${GREEN}SwiftFormat complete${NC}"
else
    echo -e "${YELLOW}SwiftFormat not installed. Run: brew install swiftformat${NC}"
fi

# Run SwiftLint with autocorrect
if command -v swiftlint &> /dev/null; then
    swiftlint lint --fix --quiet 2>/dev/null || true
    echo -e "${GREEN}SwiftLint autocorrect complete${NC}"

    # Show remaining issues
    echo -e "${YELLOW}Checking for remaining issues...${NC}"
    swiftlint lint --quiet || true
else
    echo -e "${YELLOW}SwiftLint not installed. Run: brew install swiftlint${NC}"
fi

echo -e "${GREEN}Done!${NC}"
