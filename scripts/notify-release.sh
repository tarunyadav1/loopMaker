#!/bin/bash
set -euo pipefail

# Sends a release notification to Discord/Slack/custom webhook.
#
# Required env:
#   RELEASE_NOTIFICATION_WEBHOOK_URL
#
# Optional env:
#   RELEASE_NOTIFICATION_WEBHOOK_TOKEN   # Sent as Bearer token
#   RELEASE_NOTIFICATION_CHANNEL          # Included in payload metadata
#   RELEASE_NOTIFICATION_KIND             # discord (default) | slack | generic
#
# Usage:
#   ./scripts/notify-release.sh \
#     --app "LoopMaker" \
#     --version "1.0.1" \
#     --build "2" \
#     --download-url "https://..." \
#     --appcast-url "https://..." \
#     --release-notes "Bug fixes and improvements."

WEBHOOK_URL="${RELEASE_NOTIFICATION_WEBHOOK_URL:-}"
WEBHOOK_TOKEN="${RELEASE_NOTIFICATION_WEBHOOK_TOKEN:-}"
WEBHOOK_KIND="${RELEASE_NOTIFICATION_KIND:-discord}"
WEBHOOK_CHANNEL="${RELEASE_NOTIFICATION_CHANNEL:-}"

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
      echo "[notify-release] Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$WEBHOOK_URL" ]]; then
  echo "[notify-release] Skipping: RELEASE_NOTIFICATION_WEBHOOK_URL is not set."
  exit 0
fi

if [[ -z "$APP_NAME" || -z "$VERSION" || -z "$BUILD_NUMBER" || -z "$DOWNLOAD_URL" ]]; then
  echo "[notify-release] Missing required arguments." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[notify-release] jq is required." >&2
  exit 1
fi

timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

case "$WEBHOOK_KIND" in
  discord)
    payload="$(jq -n \
      --arg app "$APP_NAME" \
      --arg version "$VERSION" \
      --arg build "$BUILD_NUMBER" \
      --arg download "$DOWNLOAD_URL" \
      --arg appcast "$APPCAST_URL" \
      --arg notes "$RELEASE_NOTES" \
      --arg channel "$WEBHOOK_CHANNEL" \
      --arg ts "$timestamp" \
      '{
        "embeds": [
          {
            "title": ($app + " release published"),
            "description": $notes,
            "color": 5763719,
            "timestamp": $ts,
            "fields": [
              { "name": "Version", "value": $version, "inline": true },
              { "name": "Build", "value": $build, "inline": true },
              { "name": "Download", "value": $download, "inline": false },
              { "name": "Appcast", "value": $appcast, "inline": false }
            ] + (if $channel == "" then [] else [{ "name": "Channel", "value": $channel, "inline": true }] end)
          }
        ]
      }')"
    ;;
  slack)
    payload="$(jq -n \
      --arg app "$APP_NAME" \
      --arg version "$VERSION" \
      --arg build "$BUILD_NUMBER" \
      --arg download "$DOWNLOAD_URL" \
      --arg appcast "$APPCAST_URL" \
      --arg notes "$RELEASE_NOTES" \
      --arg channel "$WEBHOOK_CHANNEL" \
      '{
        "text": ("🚀 " + $app + " " + $version + " (build " + $build + ") is live."),
        "blocks": [
          { "type": "section", "text": { "type": "mrkdwn", "text": ("*"+$app+"* release published") } },
          { "type": "section", "text": { "type": "mrkdwn", "text": $notes } },
          { "type": "section", "fields": [
            { "type": "mrkdwn", "text": ("*Version*\n" + $version) },
            { "type": "mrkdwn", "text": ("*Build*\n" + $build) }
          ]},
          { "type": "section", "text": { "type": "mrkdwn", "text": ("*Download*\n" + $download) } },
          { "type": "section", "text": { "type": "mrkdwn", "text": ("*Appcast*\n" + $appcast) } }
        ] + (if $channel == "" then [] else [{ "type": "context", "elements": [{ "type": "mrkdwn", "text": ("Channel: " + $channel) }] }] end)
      }')"
    ;;
  generic)
    payload="$(jq -n \
      --arg app "$APP_NAME" \
      --arg version "$VERSION" \
      --arg build "$BUILD_NUMBER" \
      --arg download "$DOWNLOAD_URL" \
      --arg appcast "$APPCAST_URL" \
      --arg notes "$RELEASE_NOTES" \
      --arg channel "$WEBHOOK_CHANNEL" \
      --arg ts "$timestamp" \
      '{
        "app_name": $app,
        "version": $version,
        "build": $build,
        "download_url": $download,
        "appcast_url": $appcast,
        "release_notes": $notes,
        "channel": $channel,
        "released_at": $ts
      }')"
    ;;
  *)
    echo "[notify-release] Unknown RELEASE_NOTIFICATION_KIND: $WEBHOOK_KIND" >&2
    exit 1
    ;;
esac

auth_headers=()
if [[ -n "$WEBHOOK_TOKEN" ]]; then
  auth_headers=(-H "Authorization: Bearer $WEBHOOK_TOKEN")
fi

http_code="$(
  curl -sS -o /tmp/loopmaker-release-notify-response.$$ -w "%{http_code}" \
    -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    "${auth_headers[@]}" \
    --data "$payload"
)"

if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
  echo "[notify-release] Notification failed (HTTP $http_code)." >&2
  cat /tmp/loopmaker-release-notify-response.$$ >&2 || true
  rm -f /tmp/loopmaker-release-notify-response.$$ || true
  exit 1
fi

rm -f /tmp/loopmaker-release-notify-response.$$ || true
echo "[notify-release] Notification delivered."
