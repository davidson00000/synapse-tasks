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

# 1) create & boot simulator
UDID=$(xcrun simctl create "CI-Temp-$(date +%s)" "$DEVTYPE" "$RUNTIME")
echo "[info] Created simulator: $UDID"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b

# 2) build for that device
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
set +e
xcrun simctl install "$UDID" "$APP_PATH"
RC=$?
set -e
if [ $RC -ne 0 ]; then
  echo "[error] install failed (rc=$RC). Info.plist dump:"
  /usr/libexec/PlistBuddy -c "Print" "$APP_PATH/Info.plist" || true
  exit $RC
fi

# helper: launch with env and take screenshot
capture_env () {
  local name="$1"; shift
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" --env "$@"
  sleep 2
  xcrun simctl io "$UDID" screenshot "$ARTIFACTS/$name.png"
}

# 6) home & default
sleep 1
xcrun simctl io "$UDID" screenshot "$ARTIFACTS/01_home.png"
xcrun simctl launch "$UDID" "$BUNDLE_ID" || true
sleep 2
xcrun simctl io "$UDID" screenshot "$ARTIFACTS/02_app_default.png"

# 7) distinct screens via ENV (app expects TASKS_* keys)
capture_env "03_list"  TASKS_SCREENSHOT_TAB=list
capture_env "04_board" TASKS_SCREENSHOT_TAB=board
capture_env "05_week"  TASKS_SCREENSHOT_TAB=week TASKS_SELECTED_WEEKDAY=thu

# 8) cleanup
xcrun simctl shutdown "$UDID"
xcrun simctl delete "$UDID"
echo "[info] Screenshots -> $ARTIFACTS"

