#!/bin/bash
set -euo pipefail

# Reset LoopMaker to a "fresh install" state on this Mac:
# - stops app + backend
# - deletes Application Support data (venv, model checkpoints, tracks)
# - deletes caches + HTTP URLSession storage
# - deletes UserDefaults plist(s)
# - deletes stored license key from Keychain (if present)
#
# Optional:
#   LOOPMAKER_RESET_HF_CACHE=1  also deletes ~/.cache/huggingface

APP_NAME="LoopMaker"
BUNDLE_ID="com.loopmaker.LoopMaker"

echo "[*] Quitting ${APP_NAME} (if running)..."
osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
sleep 1
killall "${APP_NAME}" >/dev/null 2>&1 || true

PID_FILE="${HOME}/Library/Application Support/${APP_NAME}/backend/pid"
if [[ -f "${PID_FILE}" ]]; then
  pid="$(cut -d: -f1 "${PID_FILE}" | tr -d '[:space:]' || true)"
  if [[ -n "${pid}" ]]; then
    echo "[*] Stopping backend process ${pid}..."
    kill "${pid}" >/dev/null 2>&1 || true
    sleep 1
    if kill -0 "${pid}" >/dev/null 2>&1; then
      kill -9 "${pid}" >/dev/null 2>&1 || true
    fi
  fi
fi

# Ensure the dev port range is free (avoids confusing "port in use" errors).
for port in 8000 8001 8002 8003; do
  pids="$(lsof -iTCP:${port} -sTCP:LISTEN -t 2>/dev/null || true)"
  if [[ -n "${pids}" ]]; then
    echo "[*] Killing process(es) listening on ${port}: ${pids}"
    kill ${pids} >/dev/null 2>&1 || true
  fi
done
sleep 1
for port in 8000 8001 8002 8003; do
  pids="$(lsof -iTCP:${port} -sTCP:LISTEN -t 2>/dev/null || true)"
  if [[ -n "${pids}" ]]; then
    kill -9 ${pids} >/dev/null 2>&1 || true
  fi
done

echo "[*] Removing app data..."
rm -rf "${HOME}/Library/Application Support/${APP_NAME}"
rm -rf "${HOME}/Library/Caches/${APP_NAME}"
rm -rf "${HOME}/Library/HTTPStorages/${APP_NAME}"
rm -f "${HOME}/Library/Preferences/${APP_NAME}.plist"
rm -f "${HOME}/Library/Preferences/${BUNDLE_ID}.plist"
rm -rf "${HOME}/Library/Saved Application State/${BUNDLE_ID}.savedState"

echo "[*] Removing stored license key from Keychain (if present)..."
security delete-generic-password -s "com.loopmaker.license" -a "license_key" >/dev/null 2>&1 || true

if [[ "${LOOPMAKER_RESET_HF_CACHE:-}" == "1" ]]; then
  echo "[*] Removing HuggingFace cache (~/.cache/huggingface)..."
  rm -rf "${HOME}/.cache/huggingface"
fi

echo "[*] Reset complete."

