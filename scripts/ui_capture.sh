#!/usr/bin/env bash
set -euo pipefail

# Usage:
# scripts/ui_capture.sh \
#   --scheme "SynapseTasks" \
#   --derived-data "build" \
#   --udid "$UDID" \
#   --bundle-id "$BUNDLE_ID" \
#   --app-path "$APP_PATH" \
#   --screenshot "artifacts/ui/board_mon.png" \
#   [--runtime <runtime-id>] [--devtype <device-type-id>]

SCHEME=""
DERIVED_DATA=""
UDID=""
BUNDLE_ID=""
APP_PATH=""
OUTPUT=""
RUNTIME=""
DEVTYPE=""

TAB="${TASKS_SCREENSHOT_TAB:-board}"
WEEKDAY="${TASKS_SELECTED_WEEKDAY:-mon}"

usage() {
  cat >&2 <<EOF
Usage: $0 [options]
  --scheme <name>
  --project <path>               (unused; reserved)
  --derived-data <path>
  --udid <simulator-udid>
  --bundle-id <bundle-id>
  --app-path <path-to-app>
  --screenshot <output-path>     (required)
  --runtime <runtime-id>         (optional; auto if not given)
  --devtype <device-type-id>     (optional; default iPhone 15)
Env:
  TASKS_SCREENSHOT_TAB=[board|list|week] (default: board)
  TASKS_SELECTED_WEEKDAY=[mon|tue|wed|thu|fri|sat|sun] (default: mon)
EOF
  exit 1
}

# -------- Parse Args --------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme)         SCHEME="$2"; shift 2 ;;
    --project)        shift 2 ;; # reserved
    --derived-data)   DERIVED_DATA="$2"; shift 2 ;;
    --udid)           UDID="$2"; shift 2 ;;
    --bundle-id)      BUNDLE_ID="$2"; shift 2 ;;
    --app-path)       APP_PATH="$2"; shift 2 ;;
    --screenshot)     OUTPUT="$2"; shift 2 ;;
    --runtime)        RUNTIME="$2"; shift 2 ;;
    --devtype)        DEVTYPE="$2"; shift 2 ;;
    -h|--help)        usage ;;
    *) echo "Unknown arg: $1" >&2; usage ;;
  esac
done

if [[ -z "${OUTPUT}" ]]; then
  echo "Error: --screenshot is required" >&2
  usage
fi

# -------- Resolve Simulator --------
if [[ -z "${UDID}" ]]; then
  # Try create one if not found
  if [[ -z "${RUNTIME}" ]]; then
    RUNTIME="$(xcrun simctl list runtimes | awk -F '[()]' '/iOS .* \(.*\)/ {print $2}' | tail -n1 || true)"
  fi
  DEVTYPE="${DEVTYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-15}"
  xcrun simctl create "CI iPhone 15 (auto)" "${DEVTYPE}" "${RUNTIME}" >/dev/null
  UDID="$(xcrun simctl list devices | awk -F '[()]' '/CI iPhone 15 \(auto\)/ {print $2; exit}')"
fi

xcrun simctl boot "${UDID}" || true

# -------- Install app if path provided --------
if [[ -n "${APP_PATH}" ]]; then
  xcrun simctl install "${UDID}" "${APP_PATH}" || true
fi

# -------- Launch with ENV --------
echo "[ui_capture] Launching with ENV: TAB=${TAB}, WEEKDAY=${WEEKDAY}"
xcrun simctl terminate "${UDID}" "${BUNDLE_ID}" || true
xcrun simctl launch \
  --terminate-running-app \
  --console \
  --env TASKS_SCREENSHOT_TAB="${TAB}" \
  --env TASKS_SELECTED_WEEKDAY="${WEEKDAY}" \
  "${UDID}" "${BUNDLE_ID}" || {
    echo "[ui_capture] First launch failed. Retrying once after boot wait..."
    sleep 3
    xcrun simctl boot "${UDID}" || true
    xcrun simctl launch \
      --terminate-running-app \
      --console \
      --env TASKS_SCREENSHOT_TAB="${TAB}" \
      --env TASKS_SELECTED_WEEKDAY="${WEEKDAY}" \
      "${UDID}" "${BUNDLE_ID}"
  }

# -------- Wait UI stabilization (retry) --------
# 低速ランナー対策で最大 ~8秒待機
for s in 3 2 2 1; do
  sleep "${s}"
done

# -------- Screenshot --------
mkdir -p "$(dirname "${OUTPUT}")"
xcrun simctl io "${UDID}" screenshot "${OUTPUT}"
echo "[ui_capture] Saved screenshot -> ${OUTPUT}"

