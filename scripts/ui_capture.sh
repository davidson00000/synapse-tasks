#!/usr/bin/env bash
set -euo pipefail

SCHEME="${SCHEME:-SynapseTasks}"
PROJECT="${PROJECT:-SynapseTasks.xcodeproj}"
RUNTIME="${RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-18-2}"
DEVTYPE="${DEVTYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-15}"
DERIVED="${DERIVED:-$PWD/build/ci-derived}"
ARTIFACTS="${ARTIFACTS:-artifacts/screenshots}"

mkdir -p "$ARTIFACTS"
echo "[info] Project : $PROJECT"
echo "[info] Scheme  : $SCHEME"
echo "[info] Using runtime: $RUNTIME"
echo "[info] Device type  : $DEVTYPE"

# 1) boot simulator
UDID=$(xcrun simctl create "CI-Temp-$(date +%s)" "$DEVTYPE" "$RUNTIME")
echo "[info] Created simulator: $UDID"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b

# 2) build
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "id=$UDID" \
  -derivedDataPath "$DERIVED" \
  build | xcpretty

# 3) resolve .app
APP_PATH="$(/usr/bin/find "$DERIVED/Build/Products/Debug-iphonesimulator" -type d -name "*.app" -print -quit)"
if [ -z "${APP_PATH:-}" ] || [ ! -d "$APP_PATH" ]; then
  echo "[error] .app not found under $DERIVED/Build/Products/Debug-iphonesimulator"
  /usr/bin/find "$DERIVED/Build/Products/Debug-iphonesimulator" -maxdepth 3 -type d -name "*.app" -print || true
  exit 1
fi
echo "[info] APP_PATH: $APP_PATH"

# 4) bundle id
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist")
echo "[info] BundleID: $BUNDLE_ID"

# 5) install
if ! xcrun simctl install "$UDID" "$APP_PATH"; then
  echo "[error] install failed. Info.plist:"
  /usr/libexec/PlistBuddy -c "Print" "$APP_PATH/Info.plist" || true
  exit 1
fi

# helper: launch with ENV + ARGS and take screenshot
capture () {
  local name="$1"; shift
  local tab="$1"; shift || true
  local weekday="${1:-}"

  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

  # pass both env and args (app may read either)
  local envs=(--env "TASKS_SCREENSHOT_TAB=$tab")
  local args=(--args "TASKS_SCREENSHOT_TAB=$tab")
  if [ -n "$weekday" ]; then
    envs+=(--env "TASKS_SELECTED_WEEKDAY=$weekday")
    args+=( "TASKS_SELECTED_WEEKDAY=$weekday" )
  fi

  xcrun simctl launch "$UDID" "$BUNDLE_ID" "${envs[@]}" "${args[@]}" || true
  sleep 2
  xcrun simctl io "$UDID" screenshot "$ARTIFACTS/$name.png"
}

# 6) home & default
sleep 1
xcrun simctl io "$UDID" screenshot "$ARTIFACTS/01_home.png"
xcrun simctl launch "$UDID" "$BUNDLE_ID" || true
sleep 2
xcrun simctl io "$UDID" screenshot "$ARTIFACTS/02_app_default.png"

# 7) distinct screens
capture "03_list"  "list"
capture "04_board" "board"
capture "05_week"  "week" "thu"

# 8) cleanup
xcrun simctl shutdown "$UDID"
xcrun simctl delete "$UDID"
echo "[info] Screenshots -> $ARTIFACTS"

