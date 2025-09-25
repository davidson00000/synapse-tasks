#!/usr/bin/env bash
set -euo pipefail

# 入力（環境変数で上書き可能）
UDID="${UDID:-}"
SCHEME="${SCHEME:-SynapseTasks}"
CONFIG="${CONFIG:-Debug}"
OUT="ui_captures/$(date +%F)"
DEVICE_NAME="${DEVICE_NAME:-iPhone 15}"

mkdir -p "$OUT"

DEVICE_UDID="${UDID:-}"

if [ -z "$DEVICE_UDID" ]; then
  DEVICE_UDID="$(xcrun simctl list devices | awk -v name="$DEVICE_NAME" '
    /-- iOS/ {ios=1} ios && $0 ~ name { if ($0 ~ /(Booted)/){print $NF; exit} else {udid=$NF} }
    END{gsub(/[()]/,"",udid); print udid }')"
fi

# ない場合はランタイム自動検出→作成
if [ -z "$DEVICE_UDID" ]; then
  # pick first available iPhone runtime+devicetype as fallback (CI friendly)
  RUNTIME=$(xcrun simctl list runtimes | awk -F '[()]' '/iOS .* - com.apple.CoreSimulator.SimRuntime/ && $0 ~ "Available" {print $2; exit}')
  TYPE=$(xcrun simctl list devicetypes | awk -F '[()]' '/iPhone/ {print $2; exit}')
  if [ -n "$RUNTIME" ] && [ -n "$TYPE" ]; then
    xcrun simctl create "UI Shot" "com.apple.CoreSimulator.SimDeviceType.${TYPE}" "$RUNTIME" >/dev/null
    DEVICE_UDID="$(xcrun simctl list devices | awk -F '[()]' '/UI Shot/ {print $2; exit}')"
  fi
fi

if [ -z "$DEVICE_UDID" ]; then
  echo "ERROR: No simulator UDID resolved. Exiting." >&2
  exit 2
fi

echo "Using UDID: $DEVICE_UDID"

# .app の実パスを iphonesimulator で解決
APP_PATH=$(xcodebuild -scheme "$SCHEME" -configuration "$CONFIG" -sdk iphonesimulator -showBuildSettings \
  | awk -F' = ' '/TARGET_BUILD_DIR/{t=$2}/WRAPPER_NAME/{w=$2}END{print t"/"w}')
[ -z "$APP_PATH" ] && { echo "ERROR: APP_PATH could not be resolved."; exit 3; }
[ -d "$APP_PATH" ] || { echo "ERROR: App not found at $APP_PATH. Run: make build"; exit 3; }
echo "Using APP_PATH: $APP_PATH"

# BUNDLE_ID を Info.plist → だめなら PRODUCT_BUNDLE_IDENTIFIER でフォールバック
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist" 2>/dev/null || true)
if [ -z "$BUNDLE_ID" ]; then
  BUNDLE_ID=$(xcodebuild -scheme "$SCHEME" -configuration "$CONFIG" -sdk iphonesimulator -showBuildSettings \
    | awk -F' = ' '/^ *PRODUCT_BUNDLE_IDENTIFIER /{print $2; exit}')
fi
[ -z "$BUNDLE_ID" ] && { echo "ERROR: BUNDLE_ID not resolved."; exit 4; }
echo "Using BUNDLE_ID: $BUNDLE_ID"

# CoreSimulator の軽いクリーン→ブート
xcrun simctl shutdown "$DEVICE_UDID" 2>/dev/null || true
for p in Simulator com.apple.CoreSimulator.CoreSimulatorService; do killall -9 "$p" 2>/dev/null || true; done
sleep 1
for i in 1 2 3; do xcrun simctl boot "$DEVICE_UDID" 2>/dev/null && break || sleep $((i*2)); done
xcrun simctl bootstatus "$DEVICE_UDID" -b

# インストール（都度 terminate しながら撮影）
xcrun simctl install "$DEVICE_UDID" "$APP_PATH"

launch_for_tab() {
  local tab="$1"
  local weekday="${2:-5}"
  echo "[env] TASKS_FORCE_SEED=1 TASKS_DISABLE_PERSISTENCE=1 TASKS_SCREENSHOT_TAB=$tab TASKS_SELECTED_WEEKDAY=${weekday:--}"
  xcrun simctl terminate "$DEVICE_UDID" "$BUNDLE_ID" 2>/dev/null || true
  if [ -n "$weekday" ]; then
    xcrun simctl launch --terminate-running-process --console-pty \
      --env TASKS_FORCE_SEED=1 \
      --env TASKS_DISABLE_PERSISTENCE=1 \
      --env TASKS_SCREENSHOT_TAB="$tab" \
      --env TASKS_SELECTED_WEEKDAY="$weekday" \
      "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null
  else
    xcrun simctl launch --terminate-running-process --console-pty \
      --env TASKS_FORCE_SEED=1 \
      --env TASKS_DISABLE_PERSISTENCE=1 \
      --env TASKS_SCREENSHOT_TAB="$tab" \
      "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null
  fi
  sleep 1.0
}

# スクショ（3回リトライ）
shot() {
  local name="$1"
  for i in 1 2 3; do
    if xcrun simctl io "$DEVICE_UDID" screenshot "$OUT/${name}.png" 2>/dev/null; then
      echo "Saved: $OUT/${name}.png"; return 0
    fi
    sleep $((i*2))
  done
  echo "WARN: screenshot $name failed"
}

launch_for_tab list
shot 01_home

launch_for_tab board
shot 02_board

launch_for_tab weekly 5
shot 03_weekly

echo "Screenshots -> $OUT"
