#!/bin/bash
set -euo pipefail

# Pushes latest release metadata to your product backend (e.g. Gumroad updater worker).
#
# Required env:
#   PRODUCT_UPDATE_ENDPOINT
#
# Optional env:
#   PRODUCT_UPDATE_TOKEN            # Sent as Bearer token
#   PRODUCT_UPDATE_TIMEOUT_SECONDS  # Default: 20
#
# Usage:
#   ./scripts/update-product.sh \
#     --app "LoopMaker" \
#     --version "1.0.1" \
#     --build "2" \
#     --download-url "https://..." \
#     --appcast-url "https://..." \
#     --release-notes "Bug fixes and improvements."

ENDPOINT="${PRODUCT_UPDATE_ENDPOINT:-}"
TOKEN="${PRODUCT_UPDATE_TOKEN:-}"
TIMEOUT="${PRODUCT_UPDATE_TIMEOUT_SECONDS:-20}"

APP_NAME=""
VERSION=""
BUILD_NUMBER=""
DOWNLOAD_URL=""
APPCAST_URL=""
RELEASE_NOTES="Bug fixes and improvements."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      APP_NAME="$2"
      shift 2
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    --build)
      BUILD_NUMBER="$2"
      shift 2
      ;;
    --download-url)
      DOWNLOAD_URL="$2"
      shift 2
      ;;
    --appcast-url)
      APPCAST_URL="$2"
      shift 2
      ;;
    --release-notes)
      RELEASE_NOTES="$2"
      shift 2
      ;;
    *)
      echo "[update-product] Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$ENDPOINT" ]]; then
  echo "[update-product] Skipping: PRODUCT_UPDATE_ENDPOINT is not set."
  exit 0
fi

if [[ -z "$APP_NAME" || -z "$VERSION" || -z "$BUILD_NUMBER" || -z "$DOWNLOAD_URL" ]]; then
  echo "[update-product] Missing required arguments." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[update-product] jq is required." >&2
  exit 1
fi

timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

payload="$(jq -n \
  --arg app "$APP_NAME" \
  --arg version "$VERSION" \
  --arg build "$BUILD_NUMBER" \
  --arg download "$DOWNLOAD_URL" \
  --arg appcast "$APPCAST_URL" \
  --arg notes "$RELEASE_NOTES" \
  --arg ts "$timestamp" \
  '{
    "app_name": $app,
    "version": $version,
    "build": $build,
    "download_url": $download,
    "appcast_url": $appcast,
    "release_notes": $notes,
    "released_at": $ts
  }')"

auth_headers=()
if [[ -n "$TOKEN" ]]; then
  auth_headers=(-H "Authorization: Bearer $TOKEN")
fi

http_code="$(
  curl -sS -o /tmp/loopmaker-product-update-response.$$ -w "%{http_code}" \
    -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    "${auth_headers[@]}" \
    --max-time "$TIMEOUT" \
    --data "$payload"
)"

if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
  echo "[update-product] Product update failed (HTTP $http_code)." >&2
  cat /tmp/loopmaker-product-update-response.$$ >&2 || true
  rm -f /tmp/loopmaker-product-update-response.$$ || true
  exit 1
fi

rm -f /tmp/loopmaker-product-update-response.$$ || true
echo "[update-product] Product endpoint updated."
