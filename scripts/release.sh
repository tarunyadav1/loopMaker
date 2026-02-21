#!/bin/bash
set -euo pipefail

# LoopMaker Production Release Script
#
# End-to-end flow:
# 1) Build and sign LoopMaker.app
# 2) Create ZIP/DMG release artifact
# 3) Notarize + staple
# 4) Generate Sparkle EdDSA signature
# 5) Upload artifact to Cloudflare R2
# 6) Update appcast via updates worker admin API
# 7) Optionally update product backend + send release notification webhook

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Load local environment overrides when present.
if [[ -f ".env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source ".env"
  set +a
fi

# Core configuration
APP_NAME="LoopMaker"
APP_BUNDLE="build/${APP_NAME}.app"
RELEASES_DIR="releases"
SPARKLE_BIN=".build/artifacts/sparkle/Sparkle/bin"
UPDATES_URL="${UPDATES_URL:-https://loopmaker-updates.tarunyadav9761.workers.dev}"
UPDATES_BUCKET="${UPDATES_BUCKET:-loopmaker-updates}"
NOTARIZATION_PROFILE="${NOTARIZATION_PROFILE:-LoopMaker-Notarization}"
SPARKLE_KEYCHAIN_ACCOUNT="${SPARKLE_KEYCHAIN_ACCOUNT:-loopmaker}"

# Secrets / environment
ADMIN_SECRET="${LOOPMAKER_ADMIN_SECRET:-}"
TEAM_ID="${TEAM_ID:-${APPLE_TEAM_ID:-2M3JKYS79P}}"
DEVELOPER_IDENTITY="${DEVELOPER_IDENTITY:-}"

# Flags
RELEASE_FORMAT="${RELEASE_FORMAT:-zip}" # zip | dmg
SKIP_BUILD=false
SKIP_NOTARIZATION=false
ASSUME_YES=false
RUN_PRODUCT_UPDATE="${RUN_PRODUCT_UPDATE:-false}"
RUN_RELEASE_NOTIFICATION="${RUN_RELEASE_NOTIFICATION:-false}"

# Runtime values populated later
SIGNING_IDENTITY=""
ARCHIVE_NAME=""
ARCHIVE_PATH=""
FILE_SIZE=""
VERSION=""
BUILD_NUMBER=""
MIN_SYSTEM_VERSION="14.0"
SIGNATURE=""
RELEASE_NOTES="Bug fixes and improvements."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[*]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_info() { echo -e "${CYAN}[i]${NC} $1"; }

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    print_error "Missing required command: $1"
    exit 1
  fi
}

to_bool() {
  local value
  value="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
  [[ "$value" == "1" || "$value" == "true" || "$value" == "yes" || "$value" == "y" ]]
}

check_prerequisites() {
  print_status "Checking prerequisites..."

  require_command jq
  require_command curl
  require_command npx
  require_command codesign
  require_command spctl
  require_command xcrun
  require_command security

  if [[ ! -f "$SPARKLE_BIN/sign_update" ]]; then
    print_error "Sparkle sign_update not found at $SPARKLE_BIN/sign_update"
    print_info "Run: swift package resolve && swift build -c release"
    exit 1
  fi

  if [[ -z "$ADMIN_SECRET" ]]; then
    print_error "LOOPMAKER_ADMIN_SECRET is required."
    print_info "Export it first: export LOOPMAKER_ADMIN_SECRET='your-admin-secret'"
    exit 1
  fi

  if [[ "$RELEASE_FORMAT" != "zip" && "$RELEASE_FORMAT" != "dmg" ]]; then
    print_error "Invalid release format: $RELEASE_FORMAT (expected: zip or dmg)"
    exit 1
  fi

  if [[ "$SKIP_NOTARIZATION" == "false" ]]; then
    if ! xcrun notarytool history --keychain-profile "$NOTARIZATION_PROFILE" >/dev/null 2>&1; then
      print_error "Notarization profile '$NOTARIZATION_PROFILE' not found in keychain."
      print_info "Run:"
      print_info "  xcrun notarytool store-credentials \"$NOTARIZATION_PROFILE\" \\"
      print_info "    --apple-id \"YOUR_APPLE_ID\" \\"
      print_info "    --team-id \"YOUR_TEAM_ID\" \\"
      print_info "    --password \"APP_SPECIFIC_PASSWORD\""
      exit 1
    fi
  else
    print_warning "Notarization is disabled (--skip-notarization)."
  fi
}

resolve_signing_identity() {
  if [[ -n "$DEVELOPER_IDENTITY" ]]; then
    SIGNING_IDENTITY="$DEVELOPER_IDENTITY"
    print_status "Using provided signing identity: $SIGNING_IDENTITY"
    return
  fi

  SIGNING_IDENTITY="$(
    security find-identity -v -p codesigning 2>/dev/null \
      | sed -n 's/.*"\(Developer ID Application[^"]*\)".*/\1/p' \
      | head -n 1
  )"

  if [[ -z "$SIGNING_IDENTITY" ]]; then
    print_error "No Developer ID Application signing identity found."
    print_info "Install a Developer ID certificate or set DEVELOPER_IDENTITY explicitly."
    exit 1
  fi

  if [[ -n "$TEAM_ID" && "$SIGNING_IDENTITY" != *"($TEAM_ID)"* ]]; then
    print_warning "Selected signing identity does not match TEAM_ID=$TEAM_ID"
  fi

  print_status "Resolved signing identity: $SIGNING_IDENTITY"
}

build_release_app() {
  if [[ "$SKIP_BUILD" == "true" ]]; then
    print_warning "Skipping build step (--skip-build)."
  else
    print_status "Building release app bundle..."
    make release-app
  fi

  if [[ ! -d "$APP_BUNDLE" ]]; then
    print_error "App bundle not found at $APP_BUNDLE"
    exit 1
  fi
}

sign_app_bundle() {
  print_status "Signing app bundle with Developer ID..."

  local entitlements="LoopMaker/LoopMaker.entitlements"
  local pythonEntitlements="scripts/python-dyld.entitlements"

  # Remove python.o (LLVM bitcode wrapper) - can't be properly notarized
  find "$APP_BUNDLE" -name "python.o" -delete 2>/dev/null && print_status "Removed python.o (LLVM bitcode, not notarizable)" || true

  # Remove AppleDouble/resource fork files (._*) that break code signatures.
  # These get embedded in Python.framework and invalidate sealed resources.
  print_status "Cleaning resource forks and caches from app bundle..."
  find "$APP_BUNDLE" -name '._*' -delete 2>/dev/null || true
  find "$APP_BUNDLE" -name '.__*' -delete 2>/dev/null || true
  find "$APP_BUNDLE" -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
  find "$APP_BUNDLE" -name '*.pyc' -delete 2>/dev/null || true
  dot_clean "$APP_BUNDLE" 2>/dev/null || true
  xattr -cr "$APP_BUNDLE" 2>/dev/null || true

  # Sign executable files first (inside-out order)
  while IFS= read -r binary; do
    if file "$binary" | grep -q "Mach-O"; then
      if [[ "$binary" == *"/Python.framework/Versions/"*/bin/python3.11 ]]; then
        codesign --force --timestamp --options runtime --entitlements "$pythonEntitlements" --sign "$SIGNING_IDENTITY" "$binary"
      else
        codesign --force --timestamp --options runtime --sign "$SIGNING_IDENTITY" "$binary"
      fi
    fi
  done < <(find "$APP_BUNDLE" -type f \( -name "*.dylib" -o -name "*.so" -o -name "*.o" -o -name "*.a" -o -perm -111 \))

  # Sign nested bundles and frameworks (inside-out: .app/.xpc first, then .framework)
  while IFS= read -r bundle; do
    codesign --force --timestamp --options runtime --sign "$SIGNING_IDENTITY" "$bundle"
  done < <(find "$APP_BUNDLE/Contents/Frameworks" -type d \( -name "*.xpc" -o -name "*.app" \) 2>/dev/null || true)

  while IFS= read -r bundle; do
    codesign --force --timestamp --options runtime --sign "$SIGNING_IDENTITY" "$bundle"
  done < <(find "$APP_BUNDLE/Contents/Frameworks" -maxdepth 2 -type d -name "*.framework" 2>/dev/null || true)

  # Sign main app bundle (final signature)
  if [[ -f "$entitlements" ]]; then
    codesign --force --timestamp --options runtime \
      --entitlements "$entitlements" \
      --sign "$SIGNING_IDENTITY" \
      "$APP_BUNDLE"
  else
    codesign --force --timestamp --options runtime \
      --sign "$SIGNING_IDENTITY" \
      "$APP_BUNDLE"
  fi

  codesign --verify --deep --strict "$APP_BUNDLE"
  print_status "Code signing complete."
}

verify_signing_identity() {
  local signing_info
  signing_info="$(codesign -dv --verbose=2 "$APP_BUNDLE" 2>&1 || true)"
  if ! echo "$signing_info" | grep -q "Authority=Developer ID Application"; then
    print_error "App is not signed with a Developer ID Application certificate."
    echo "$signing_info"
    exit 1
  fi
}

get_version_info() {
  local plist="$APP_BUNDLE/Contents/Info.plist"
  VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist")"
  BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$plist")"
  MIN_SYSTEM_VERSION="$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$plist" 2>/dev/null || echo "14.0")"
  print_status "Version: $VERSION (Build $BUILD_NUMBER)"
}

cleanup_resource_forks() {
  find "$APP_BUNDLE" -name '._*' -delete 2>/dev/null || true
  find "$APP_BUNDLE" -name '.__*' -delete 2>/dev/null || true
  dot_clean "$APP_BUNDLE" 2>/dev/null || true
}

create_zip() {
  print_status "Creating ZIP archive..."
  mkdir -p "$RELEASES_DIR"
  ARCHIVE_NAME="${APP_NAME}-${VERSION}.zip"
  ARCHIVE_PATH="${RELEASES_DIR}/${ARCHIVE_NAME}"
  rm -f "$ARCHIVE_PATH"

  cleanup_resource_forks
  COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "$APP_BUNDLE" "$ARCHIVE_PATH"
  FILE_SIZE="$(stat -f%z "$ARCHIVE_PATH")"
  print_status "Created: $ARCHIVE_PATH ($FILE_SIZE bytes)"
}

create_dmg() {
  print_status "Creating DMG archive..."
  mkdir -p "$RELEASES_DIR"
  ARCHIVE_NAME="${APP_NAME}-${VERSION}.dmg"
  ARCHIVE_PATH="${RELEASES_DIR}/${ARCHIVE_NAME}"
  rm -f "$ARCHIVE_PATH"

  ./scripts/create-dmg.sh "$APP_BUNDLE" "$ARCHIVE_PATH" "$APP_NAME"
  FILE_SIZE="$(stat -f%z "$ARCHIVE_PATH")"
  print_status "Created: $ARCHIVE_PATH ($FILE_SIZE bytes)"
}

create_archive() {
  if [[ "$RELEASE_FORMAT" == "dmg" ]]; then
    create_dmg
  else
    create_zip
  fi
}

notarize_archive() {
  if [[ "$SKIP_NOTARIZATION" == "true" ]]; then
    print_warning "Skipping notarization."
    return
  fi

  print_status "Submitting archive for notarization..."
  xcrun notarytool submit "$ARCHIVE_PATH" \
    --keychain-profile "$NOTARIZATION_PROFILE" \
    --wait

  if [[ "$RELEASE_FORMAT" == "dmg" ]]; then
    # For DMG: staple the DMG directly (it was notarized as-is)
    print_status "Stapling notarization ticket to DMG..."
    xcrun stapler staple "$ARCHIVE_PATH"
  else
    # For ZIP: staple the .app, then recreate ZIP with stapled app
    print_status "Stapling notarization ticket to app bundle..."
    xcrun stapler staple "$APP_BUNDLE"
  fi
}

recreate_archive_after_stapling() {
  if [[ "$SKIP_NOTARIZATION" == "true" ]]; then
    return
  fi

  # Only ZIP needs recreation (to include the stapled .app)
  # DMG was stapled directly in notarize_archive
  if [[ "$RELEASE_FORMAT" == "zip" ]]; then
    print_status "Recreating ZIP with stapled app..."
    create_archive
  fi
}

sign_release_for_sparkle() {
  print_status "Signing release with Sparkle EdDSA..."

  local output status
  set +e
  output="$("$SPARKLE_BIN/sign_update" --account "$SPARKLE_KEYCHAIN_ACCOUNT" "$ARCHIVE_PATH" 2>&1)"
  status=$?
  set -e

  if [[ $status -ne 0 ]]; then
    print_error "Sparkle sign_update failed."
    echo "$output"
    exit 1
  fi

  SIGNATURE="$(echo "$output" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' | head -n 1)"
  if [[ -z "$SIGNATURE" ]]; then
    SIGNATURE="$(echo "$output" | tail -n 1 | tr -d '[:space:]')"
  fi

  if [[ -z "$SIGNATURE" || ! "$SIGNATURE" =~ ^[A-Za-z0-9+/=]+$ ]]; then
    print_error "Failed to extract Sparkle signature."
    echo "$output"
    exit 1
  fi

  print_status "Sparkle signature generated."
}

verify_archive() {
  print_status "Verifying release artifact..."

  local verify_temp extracted_app mount_point
  verify_temp="$(mktemp -d)"
  extracted_app=""
  mount_point=""

  if [[ "$RELEASE_FORMAT" == "dmg" ]]; then
    mount_point="$(hdiutil attach "$ARCHIVE_PATH" -nobrowse -readonly | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/"))}' | head -n 1)"
    if [[ -z "$mount_point" ]]; then
      print_error "Failed to mount DMG for verification."
      rm -rf "$verify_temp"
      exit 1
    fi
    extracted_app="$mount_point/${APP_NAME}.app"
  else
    unzip -q "$ARCHIVE_PATH" -d "$verify_temp"
    extracted_app="$verify_temp/${APP_NAME}.app"
  fi

  if [[ "$SKIP_NOTARIZATION" == "false" ]]; then
    if ! xcrun stapler validate "$extracted_app" >/dev/null 2>&1; then
      print_error "Stapler validation failed for extracted app."
      xcrun stapler validate "$extracted_app" || true
      [[ -n "$mount_point" ]] && hdiutil detach "$mount_point" -quiet || true
      rm -rf "$verify_temp"
      exit 1
    fi
  fi

  codesign --verify --deep --strict "$extracted_app"
  if ! spctl -a -t exec -vv "$extracted_app" 2>&1 | grep -q "accepted"; then
    print_error "Gatekeeper rejected the extracted app."
    spctl -a -t exec -vv "$extracted_app" || true
    [[ -n "$mount_point" ]] && hdiutil detach "$mount_point" -quiet || true
    rm -rf "$verify_temp"
    exit 1
  fi

  [[ -n "$mount_point" ]] && hdiutil detach "$mount_point" -quiet || true
  rm -rf "$verify_temp"

  print_status "Artifact verification passed."
}

upload_to_r2() {
  print_status "Uploading release artifact to Cloudflare R2..."

  if [[ ! -d "cloudflare-updates-worker" ]]; then
    print_error "cloudflare-updates-worker directory not found."
    exit 1
  fi

  local archive_abs="${ROOT_DIR}/${ARCHIVE_PATH}"
  (
    cd cloudflare-updates-worker
    npx wrangler r2 object put "${UPDATES_BUCKET}/${ARCHIVE_NAME}" \
      --file="$archive_abs" \
      --content-type="application/octet-stream" \
      --remote
  )

  print_status "R2 upload complete."
}

load_release_notes() {
  RELEASE_NOTES="Bug fixes and improvements."
  if [[ -f "CHANGELOG.md" ]]; then
    local notes
    notes="$(awk "/^## \\[?${VERSION}\\]?/,/^## \\[?[0-9]/" CHANGELOG.md | head -n -1 | tail -n +2 || true)"
    if [[ -n "$notes" ]]; then
      RELEASE_NOTES="$notes"
    fi
  fi
}

update_appcast() {
  print_status "Updating appcast metadata..."
  load_release_notes

  local payload response
  payload="$(jq -n \
    --arg version "$VERSION" \
    --arg buildNumber "$BUILD_NUMBER" \
    --arg edSignature "$SIGNATURE" \
    --arg filename "$ARCHIVE_NAME" \
    --arg releaseNotes "$RELEASE_NOTES" \
    --arg minimumSystemVersion "$MIN_SYSTEM_VERSION" \
    --argjson fileSize "$FILE_SIZE" \
    '{
      version: $version,
      buildNumber: $buildNumber,
      edSignature: $edSignature,
      fileSize: $fileSize,
      filename: $filename,
      releaseNotes: $releaseNotes,
      minimumSystemVersion: $minimumSystemVersion
    }')"

  response="$(
    curl -sS -X POST "${UPDATES_URL}/admin/release" \
      -H "Authorization: Bearer ${ADMIN_SECRET}" \
      -H "Content-Type: application/json" \
      --data "$payload"
  )"

  if ! echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
    print_error "Failed to update appcast."
    echo "$response" | jq . || echo "$response"
    exit 1
  fi

  print_status "Appcast updated."
}

run_product_update() {
  if ! to_bool "$RUN_PRODUCT_UPDATE"; then
    return
  fi

  print_status "Running product update hook..."
  ./scripts/update-product.sh \
    --app "$APP_NAME" \
    --version "$VERSION" \
    --build "$BUILD_NUMBER" \
    --download-url "${UPDATES_URL}/releases/${ARCHIVE_NAME}" \
    --appcast-url "${UPDATES_URL}/appcast.xml" \
    --release-notes "$RELEASE_NOTES"
}

run_release_notification() {
  if ! to_bool "$RUN_RELEASE_NOTIFICATION"; then
    return
  fi

  print_status "Running release notification hook..."
  ./scripts/notify-release.sh \
    --app "$APP_NAME" \
    --version "$VERSION" \
    --build "$BUILD_NUMBER" \
    --download-url "${UPDATES_URL}/releases/${ARCHIVE_NAME}" \
    --appcast-url "${UPDATES_URL}/appcast.xml" \
    --release-notes "$RELEASE_NOTES"
}

print_summary() {
  echo ""
  echo -e "${GREEN}=========================================${NC}"
  echo -e "${GREEN}    Release Complete${NC}"
  echo -e "${GREEN}=========================================${NC}"
  echo ""
  echo "  App:          $APP_NAME"
  echo "  Version:      $VERSION (Build $BUILD_NUMBER)"
  echo "  Format:       $RELEASE_FORMAT"
  echo "  Artifact:     $ARCHIVE_PATH"
  echo "  Size:         $FILE_SIZE bytes"
  echo "  Notarized:    $([[ "$SKIP_NOTARIZATION" == "true" ]] && echo "No" || echo "Yes")"
  echo "  Download URL: ${UPDATES_URL}/releases/${ARCHIVE_NAME}"
  echo "  Appcast URL:  ${UPDATES_URL}/appcast.xml"
  echo "  Product Hook: $RUN_PRODUCT_UPDATE"
  echo "  Notify Hook:  $RUN_RELEASE_NOTIFICATION"
  echo ""
}

confirm_or_abort() {
  if [[ "$ASSUME_YES" == "true" ]]; then
    return
  fi

  echo ""
  echo "This will:"
  echo "  1. Build/sign ${APP_NAME}.app"
  echo "  2. Create ${RELEASE_FORMAT} artifact"
  if [[ "$SKIP_NOTARIZATION" == "false" ]]; then
    echo "  3. Notarize and staple"
  fi
  echo "  4. Sign release for Sparkle"
  echo "  5. Upload to Cloudflare R2"
  echo "  6. Update appcast metadata"
  if to_bool "$RUN_PRODUCT_UPDATE"; then
    echo "  7. Run product update hook"
  fi
  if to_bool "$RUN_RELEASE_NOTIFICATION"; then
    echo "  8. Run release notification hook"
  fi
  echo ""
  read -r -p "Continue? (y/N) " reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    print_warning "Aborted."
    exit 0
  fi
}

show_help() {
  cat <<EOF
LoopMaker Production Release Script

Usage:
  ./scripts/release.sh [options]

Options:
  --format=zip|dmg         Artifact format (default: zip)
  --skip-build             Use existing build/LoopMaker.app
  --skip-notarization      Skip Apple notarization (not for production)
  --yes                    Non-interactive confirmation
  --help                   Show this help text

Required Environment:
  LOOPMAKER_ADMIN_SECRET   Updates worker admin secret

Optional Environment:
  UPDATES_URL                     Default: ${UPDATES_URL}
  UPDATES_BUCKET                  Default: ${UPDATES_BUCKET}
  NOTARIZATION_PROFILE            Default: ${NOTARIZATION_PROFILE}
  SPARKLE_KEYCHAIN_ACCOUNT        Default: ${SPARKLE_KEYCHAIN_ACCOUNT}
  DEVELOPER_IDENTITY              Explicit Developer ID identity
  TEAM_ID                         Team ID validation hint
  RUN_PRODUCT_UPDATE              true/false (default: false)
  RUN_RELEASE_NOTIFICATION        true/false (default: false)
  PRODUCT_UPDATE_ENDPOINT         Used by scripts/update-product.sh
  PRODUCT_UPDATE_TOKEN            Used by scripts/update-product.sh
  RELEASE_NOTIFICATION_WEBHOOK_URL   Used by scripts/notify-release.sh
  RELEASE_NOTIFICATION_WEBHOOK_TOKEN Used by scripts/notify-release.sh
  RELEASE_NOTIFICATION_KIND          discord|slack|generic

Examples:
  LOOPMAKER_ADMIN_SECRET=... ./scripts/release.sh --format=zip
  LOOPMAKER_ADMIN_SECRET=... RUN_PRODUCT_UPDATE=true RUN_RELEASE_NOTIFICATION=true ./scripts/release.sh --yes
EOF
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format=*)
        RELEASE_FORMAT="${1#*=}"
        shift
        ;;
      --skip-build)
        SKIP_BUILD=true
        shift
        ;;
      --skip-notarization)
        SKIP_NOTARIZATION=true
        shift
        ;;
      --yes)
        ASSUME_YES=true
        shift
        ;;
      --help)
        show_help
        exit 0
        ;;
      *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done

  check_prerequisites
  resolve_signing_identity
  confirm_or_abort

  build_release_app
  sign_app_bundle
  verify_signing_identity
  get_version_info
  create_archive
  notarize_archive
  recreate_archive_after_stapling
  sign_release_for_sparkle
  verify_archive
  upload_to_r2
  update_appcast
  run_product_update
  run_release_notification
  print_summary
}

main "$@"
