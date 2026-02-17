#!/bin/bash
# =============================================================================
# Download Python Standalone for macOS App Bundling
# =============================================================================
#
# This script downloads the official Python.org standalone build and
# prepares it for bundling into a macOS .app bundle.
#
# Usage: ./download-python.sh [version] [output_dir]
#   version    - Python version (default: 3.11.8)
#   output_dir - Directory to extract to (default: build/python)
#
# The script will create a Python.framework directory that can be
# copied directly into Contents/Frameworks/ of your app bundle.
#
# =============================================================================

set -e

# Configuration
PYTHON_VERSION="${1:-3.11.8}"
OUTPUT_DIR="${2:-build/python}"
PYTHON_MAJOR_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f1,2)

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Downloading Python ${PYTHON_VERSION} for macOS bundling...${NC}"

# Create output directory
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

# Determine architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    PLATFORM="macos11"
    echo -e "${YELLOW}Detected Apple Silicon (arm64)${NC}"
else
    PLATFORM="macos10.9"
    echo -e "${YELLOW}Detected Intel (x86_64)${NC}"
fi

# Download URL for Python.org universal2 installer
# Note: Python.org provides universal2 binaries that work on both architectures
DOWNLOAD_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/python-${PYTHON_VERSION}-macos11.pkg"

PKG_FILE="python-${PYTHON_VERSION}.pkg"

# Download if not already present
if [ ! -f "$PKG_FILE" ]; then
    echo -e "${GREEN}Downloading from ${DOWNLOAD_URL}...${NC}"
    curl -L -o "$PKG_FILE" "$DOWNLOAD_URL"
else
    echo -e "${YELLOW}Using cached ${PKG_FILE}${NC}"
fi

# Verify download
if [ ! -f "$PKG_FILE" ]; then
    echo -e "${RED}Failed to download Python installer${NC}"
    exit 1
fi

# Extract the package
echo -e "${GREEN}Extracting Python framework...${NC}"

# Create extraction directory
EXTRACT_DIR="extracted"
rm -rf "$EXTRACT_DIR"

# Expand the pkg
pkgutil --expand-full "$PKG_FILE" "$EXTRACT_DIR"

# Find and copy the Python framework
FRAMEWORK_SOURCE=$(find "$EXTRACT_DIR" -type d -name "Python.framework" | head -1)

# Python.org's macos11 installer is a distribution pkg with subpackages.
# For the framework package, the expanded Payload directory contains the
# contents of /Library/Frameworks/Python.framework (without the outer folder).
if [ -z "$FRAMEWORK_SOURCE" ] && [ -d "$EXTRACT_DIR/Python_Framework.pkg/Payload/Versions" ]; then
    FRAMEWORK_SOURCE="$EXTRACT_DIR/Python_Framework.pkg/Payload"
fi

if [ -z "$FRAMEWORK_SOURCE" ]; then
    echo -e "${RED}Could not find Python.framework in package${NC}"
    echo -e "${YELLOW}Package contents:${NC}"
    ls -la "$EXTRACT_DIR"
    exit 1
fi

# Copy framework to output location
FRAMEWORK_DEST="Python.framework"
rm -rf "$FRAMEWORK_DEST"
cp -R "$FRAMEWORK_SOURCE" "$FRAMEWORK_DEST"

# Clean up extraction directory
rm -rf "$EXTRACT_DIR"

# Verify the framework
PYTHON_BIN="$FRAMEWORK_DEST/Versions/${PYTHON_MAJOR_MINOR}/bin/python3"
if [ -x "$PYTHON_BIN" ]; then
    echo -e "${GREEN}Python framework extracted successfully!${NC}"
    echo -e "${GREEN}Python binary: ${PYTHON_BIN}${NC}"
    # The Python.org framework binary expects to load Python.framework from /Library/Frameworks.
    # For bundling, we use DYLD_FRAMEWORK_PATH so it resolves to the local extracted framework.
    DYLD_FRAMEWORK_PATH="$(pwd)" \
    DYLD_LIBRARY_PATH="$(pwd)/${FRAMEWORK_DEST}/Versions/${PYTHON_MAJOR_MINOR}/lib" \
    "$PYTHON_BIN" --version
else
    echo -e "${RED}Python binary not found at expected location${NC}"
    echo -e "${YELLOW}Framework structure:${NC}"
    ls -la "$FRAMEWORK_DEST/Versions/"
    exit 1
fi

# Create a minimal requirements check script
cat > test_python.sh << 'EOF'
#!/bin/bash
# Test the bundled Python
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON="$SCRIPT_DIR/Python.framework/Versions/3.11/bin/python3"
echo "Testing bundled Python..."
DYLD_FRAMEWORK_PATH="$SCRIPT_DIR" DYLD_LIBRARY_PATH="$SCRIPT_DIR/Python.framework/Versions/3.11/lib" $PYTHON -c "import sys; print(f'Python {sys.version}')"
DYLD_FRAMEWORK_PATH="$SCRIPT_DIR" DYLD_LIBRARY_PATH="$SCRIPT_DIR/Python.framework/Versions/3.11/lib" $PYTHON -c "import venv; print('venv module: OK')"
DYLD_FRAMEWORK_PATH="$SCRIPT_DIR" DYLD_LIBRARY_PATH="$SCRIPT_DIR/Python.framework/Versions/3.11/lib" $PYTHON -c "import pip; print(f'pip version: {pip.__version__}')"
echo "All tests passed!"
EOF
chmod +x test_python.sh

echo ""
echo -e "${GREEN}=== Python Bundling Complete ===${NC}"
echo -e "Framework location: ${OUTPUT_DIR}/${FRAMEWORK_DEST}"
echo -e "Size: $(du -sh "$FRAMEWORK_DEST" | cut -f1)"
echo ""
echo -e "To bundle into your app:"
echo -e "  cp -R ${OUTPUT_DIR}/${FRAMEWORK_DEST} YourApp.app/Contents/Frameworks/"
echo ""
echo -e "Run ${YELLOW}./test_python.sh${NC} to verify the installation."
