#!/usr/bin/env bash
set -euo pipefail

SCHEME="${SCHEME:-SynapseTasks}"
DERIVED_DATA="${DERIVED_DATA:-build}"
UDID="${UDID:-}"
BUNDLE_ID="${BUNDLE_ID:-}"
APP_PATH="${APP_PATH:-}"
OUTPUT="${OUTPUT:-}"
RUNTIME="${RUNTIME:-}"
DEVTYPE="${DEVTYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-15}"

TAB="${TASKS_SCREENSHOT_TAB:-board}"
WEEKDAY="${TASKS_SELECTED_WEEKDAY:-mon}"

usage() {
  cat >&2 <<EOF
Usage: $0 [options]
  --scheme <name>                (default: SynapseTasks or \$SCHEME)
  --project <path>               (unused; reserved)
  --derived-data <path>          (default: build or \$DERIVED_DATA)
  --udid <simulator-udid>        (auto if not given)
  --bundle-id <bundle-id>        (auto from xcodebuild if not given)
  --app-path <path-to-app>       (auto from derived data if not given)
  --screenshot <output-path>     (default: artifacts/ui/\$TAB_\$WEEKDAY.png)
  --runtime <runtime-id>         (auto latest if not given)
  --devtype <device-type-id>     (default: iPhone 15)
Env:
  TASKS_SCREENSHOT_TAB=[board|list|week] (default: board)
  TASKS_SELECTED_WEEKDAY=[mon|tue|wed|thu|fri|sat|sun] (default: mon)
EOF
}

# -------- Parse Args (also accept ENV) --------
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
    -h|--help)        usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

# -------- Defaults if missing --------
OUTPUT="${OUTPUT:-artifacts/ui/${TAB}_${WEEKDAY}.png}"

# Resolve runtime if needed
if [[ -z "${UDID}" ]]; then
  if [[ -z "${RUNTIME}" ]]; then
    RUNTIME="$(xcrun simctl list runtimes | awk -F '[()]' '/iOS .* \(.*\)/ {print $2}' | tail -n1 || true)"
  fi
  xcrun simctl create "CI iPhone 15 (auto)" "${DEVTYPE}" "${RUNTIME}" >/dev/null || true
  UDID="$(xcrun simctl list devices | awk -F '[()]' '/CI iPhone 15 \(auto\)/ {print $2; exit}')"
  if [[ -z "${UDID}" ]]; then
    UDID="$(xcrun simctl list devices | awk -F '[()]' '/iPhone 15 .*Booted|iPhone 15 .*Shutdown/ {print $2; exit}')"
  fi
fi

# Boot
xcrun simctl boot "${UDID}" || true

# Build if app-path missing
if [[ -z "${APP_PATH}" ]]; then
  echo "[ui_capture] Building app (since --app-path not provided)"
  xcodebuild \
    -scheme "${SCHEME}" \
    -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    -derivedDataPath "${DERIVED_DATA}" \
    build | tee /tmp/ui_capture_build.log
  APP_PATH="$(find "${DERIVED_DATA}/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name '*.app' | head -n1 || true)"
fi

if [[ -z "${APP_PATH}" || ! -e "${APP_PATH}" ]]; then
  echo "[ui_capture] Error: .app not found under ${DERIVED_DATA}" >&2
  exit 70
fi

# Bundle ID auto
if [[ -z "${BUNDLE_ID}" ]]; then
  BUNDLE_ID="$(xcodebuild -showBuildSettings -scheme "${SCHEME}" -configuration Debug | awk -F' = ' '/PRODUCT_BUNDLE_IDENTIFIER/ {print $2; exit}')"
fi

# Install
xcrun simctl install "${UDID}" "${APP_PATH}" || true

echo "[ui_capture] Launching with ENV: TAB=${TAB}, WEEKDAY=${WEEKDAY}, OUTPUT=${OUTPUT}"
xcrun simctl terminate "${UDID}" "${BUNDLE_ID}" || true
xcrun simctl launch \
  --terminate-running-app \
  --console \
  --env TASKS_SCREENSHOT_TAB="${TAB}" \
  --env TASKS_SELECTED_WEEKDAY="${WEEKDAY}" \
  "${UDID}" "${BUNDLE_ID}" || {
    echo "[ui_capture] First launch failed. Retrying..."
    sleep 3
    xcrun simctl boot "${UDID}" || true
    xcrun simctl launch \
      --terminate-running-app \
      --console \
      --env TASKS_SCREENSHOT_TAB="${TAB}" \
      --env TASKS_SELECTED_WEEKDAY="${WEEKDAY}" \
      "${UDID}" "${BUNDLE_ID}"
  }

# Stabilize and screenshot
mkdir -p "$(dirname "${OUTPUT}")"
sleep 5
xcrun simctl io "${UDID}" screenshot "${OUTPUT}"
echo "[ui_capture] Saved screenshot -> ${OUTPUT}"

