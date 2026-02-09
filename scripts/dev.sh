#!/bin/bash
# LoopMaker Development Script
# Usage: ./scripts/dev.sh [clean|build|run|all]

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
APP_NAME="LoopMaker"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[DEV]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }

kill_app() {
    if pgrep -x "$APP_NAME" > /dev/null; then
        log "Killing running $APP_NAME..."
        pkill -x "$APP_NAME" 2>/dev/null || true
        sleep 1
    fi
}

clean() {
    log "Cleaning build artifacts..."
    kill_app
    rm -rf "$DERIVED_DATA/$APP_NAME-"* 2>/dev/null || true
    rm -rf .build 2>/dev/null || true
    log "Clean complete"
}

build() {
    log "Building $APP_NAME..."

    # Touch swift files to force recompilation if needed
    if [ "$FORCE" = "1" ]; then
        find "$PROJECT_DIR" -name "*.swift" -path "*/LoopMaker/*" -exec touch {} \;
        info "Forced recompilation of all Swift files"
    fi

    xcodebuild -scheme "$APP_NAME" \
        -destination 'platform=macOS' \
        -configuration Debug \
        build 2>&1 | tee /tmp/loopmaker_build.log | grep -E "(Compiling.*\.swift|error:|warning:.*LoopMaker|BUILD)" || true

    if grep -q "BUILD SUCCEEDED" /tmp/loopmaker_build.log; then
        log "Build succeeded"
    else
        error "Build failed - check /tmp/loopmaker_build.log"
        exit 1
    fi
}

run() {
    kill_app

    # Prefer launching the .app bundle so Info.plist (CFBundleIdentifier) and resources load correctly
    APP_BUNDLE=$(find "$DERIVED_DATA" -path "*/$APP_NAME-*/Build/Products/Debug/$APP_NAME.app" -type d 2>/dev/null | head -1)

    # If not found, build first
    if [ -z "$APP_BUNDLE" ]; then
        warn "App bundle not found, building first..."
        build
        APP_BUNDLE=$(find "$DERIVED_DATA" -path "*/$APP_NAME-*/Build/Products/Debug/$APP_NAME.app" -type d 2>/dev/null | head -1)
    fi

    if [ -n "$APP_BUNDLE" ]; then
        log "Launching app bundle: $APP_BUNDLE"
        # Use open so LaunchServices loads the bundle with its identifier and sandboxed prefs
        open -n "$APP_BUNDLE"
        sleep 2

        if pgrep -x "$APP_NAME" > /dev/null; then
            PID=$(pgrep -x "$APP_NAME")
            log "App running (PID: $PID)"

            # Bring to front
            osascript -e 'tell application "System Events" to set frontmost of (first process whose name is "LoopMaker") to true' 2>/dev/null || true
        else
            error "App failed to start"
            exit 1
        fi
    else
        error "Could not find $APP_NAME executable"
        exit 1
    fi
}

case "${1:-all}" in
    clean)
        clean
        ;;
    build)
        build
        ;;
    run)
        run
        ;;
    force)
        # Force full rebuild
        FORCE=1
        clean
        build
        run
        ;;
    all|*)
        kill_app
        clean
        build
        run
        ;;
esac
