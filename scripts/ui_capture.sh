#!/usr/bin/env bash
set -euo pipefail

# Allow override from env, else auto-detect later
SCHEME="${SCHEME:-}"
CONFIG="${CONFIG:-Debug}"
DERIVED="build"
OUT_DIR="$DERIVED/ui"
DEVICE_NAME="${DEVICE_NAME:-iPhone 17}"
WEEKDAY_FOR_WEEKLY="${WEEKDAY_FOR_WEEKLY:-3}"  # 1=Sun ... 7=Sat (月=2, デフォ=水=3)

mkdir -p "$OUT_DIR"
mkdir -p ui_captures/$(date +%F)
OUT="ui_captures/$(date +%F)"

# ===== Detect scheme if not provided =====
if [ -z "$SCHEME" ]; then
  echo "[info] Detecting Xcode schemes..."
  SCHEME_JSON="$(xcodebuild -list -json 2>/dev/null || true)"
  SCHEME="$(python3 - <<'PY'
import json, sys
try:
    data = json.load(sys.stdin)
    candidates = data.get("project", {}).get("schemes", []) or data.get("workspace", {}).get("schemes", [])
    for keyword in ("Synapse", "App", "SynapseTasks"):
        for scheme in candidates:
            if keyword.lower() in scheme.lower():
                print(scheme)
                raise SystemExit
    if candidates:
        print(candidates[0])
except Exception:
    pass
PY
<<<"$SCHEME_JSON")"
  if [ -z "$SCHEME" ]; then
    echo "[error] No Xcode scheme detected." >&2
    exit 2
  fi
fi

echo "[info] Using SCHEME=$SCHEME CONFIG=$CONFIG"

declare -r DEVICE_NAME

DEVICE_UDID="${UDID:-}"

if [ -z "$DEVICE_UDID" ]; then
  DEVICE_UDID="$(xcrun simctl list devices | awk -v name="$DEVICE_NAME" '
    /-- iOS/ {ios=1} ios && $0 ~ name { if ($0 ~ /(Booted)/){print $NF; exit} else {udid=$NF} }
    END{gsub(/[()]/,"",udid); print udid }')"
fi

# ない場合はランタイム自動検出→作成
if [ -z "$DEVICE_UDID" ]; then
  echo "[warn] No simulator named '$DEVICE_NAME' found; creating a fresh one..."
  RUNTIME=$(xcrun simctl list runtimes | awk -F '[()]' '/iOS .* - com.apple.CoreSimulator.SimRuntime/ && $0 ~ "Available" {print $2; exit}')
  TYPE_ID=$(xcrun simctl list devicetypes | awk -F '[()]' '/iPhone .*Pro Max|iPhone 17 Pro|iPhone 17|iPhone 16|iPhone 15/ {print $2; exit}')
  if [ -n "$RUNTIME" ] && [ -n "$TYPE_ID" ]; then
    xcrun simctl create "UI Shot" "com.apple.CoreSimulator.SimDeviceType.${TYPE_ID}" "$RUNTIME" >/dev/null
    DEVICE_UDID="$(xcrun simctl list devices | awk -F '[()]' '/UI Shot/ {print $2; exit}')"
  fi
fi

if [ -z "$DEVICE_UDID" ]; then
  echo "[error] No simulator UDID resolved. Devices:"
  xcrun simctl list devices
  exit 2
fi

echo "Using UDID: $DEVICE_UDID"

# 1) Boot simulator
xcrun simctl shutdown "$DEVICE_UDID" 2>/dev/null || true
for p in Simulator com.apple.CoreSimulator.CoreSimulatorService; do killall -9 "$p" 2>/dev/null || true; done
sleep 1
for i in 1 2 3; do xcrun simctl boot "$DEVICE_UDID" 2>/dev/null && break || sleep $((i*2)); done
xcrun simctl bootstatus "$DEVICE_UDID" -b || true

# 2) Build
echo "[info] Building... (scheme=$SCHEME, config=$CONFIG)"
xcodebuild \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "platform=iOS Simulator,id=$DEVICE_UDID" \
  -derivedDataPath "$DERIVED" \
  -quiet build

APP_PATH="$(/usr/bin/find "$DERIVED/Build/Products/$CONFIG-iphonesimulator" -maxdepth 1 -name "*.app" | head -1)"
if [ -z "${APP_PATH}" ]; then
  echo "[error] .app not found under $DERIVED/Build/Products/$CONFIG-iphonesimulator"
  echo "[debug] Available products:"
  ls -R "$DERIVED/Build/Products" || true
  exit 1
fi

echo "Using APP_PATH: $APP_PATH"

# BUNDLE_ID を Info.plist → だめなら PRODUCT_BUNDLE_IDENTIFIER でフォールバック
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist" 2>/dev/null || true)
if [ -z "$BUNDLE_ID" ]; then
  BUNDLE_ID=$(xcodebuild -scheme "$SCHEME" -configuration "$CONFIG" -sdk iphonesimulator -showBuildSettings \
    | awk -F' = ' '/^ *PRODUCT_BUNDLE_IDENTIFIER /{print $2; exit}')
fi
[ -z "$BUNDLE_ID" ] && { echo "[error] BUNDLE_ID not resolved."; exit 4; }
echo "Using BUNDLE_ID: $BUNDLE_ID"

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

launch_for_tab weekly "$WEEKDAY_FOR_WEEKLY"
shot 03_weekly

echo "Screenshots -> $OUT"
