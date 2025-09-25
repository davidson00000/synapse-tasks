#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-SynapseTasks.xcodeproj}"
SCHEME="${SCHEME:-SynapseTasks}"
echo "[info] Project : $PROJECT"
echo "[info] Scheme  : $SCHEME"

# --- scheme check ---
if ! xcodebuild -list -project "$PROJECT" | awk '/Schemes:/,0' | grep -q -E "^[[:space:]]+$SCHEME$"; then
  echo "[error] Scheme '$SCHEME' not found in $PROJECT" >&2
  xcodebuild -list -project "$PROJECT" || true
  exit 2
fi

# --- pick latest iOS runtime & a stable device type ---
RUNTIME=$(xcrun simctl list runtimes | awk '/iOS/{print $NF}' | tail -n1)
DEVTYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-15"
if [[ -z "${RUNTIME:-}" ]]; then
  echo "[error] No iOS runtimes found"; xcrun simctl list runtimes; exit 3
fi
echo "[info] Using runtime: $RUNTIME"
echo "[info] Device type  : $DEVTYPE"

# --- create a fresh temp device (avoid flaky preinstalled ones) ---
DEVICE_NAME="CI-Temp-$(date +%s)"
UDID=$(xcrun simctl create "$DEVICE_NAME" "$DEVTYPE" "$RUNTIME")
echo "[info] Created simulator: $DEVICE_NAME ($UDID)"

cleanup() {
  echo "[info] Cleanup: shutting down & deleting $UDID"
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  xcrun simctl delete   "$UDID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# --- boot with timeout & one retry ---
boot_and_wait() {
  local id="$1"
  echo "[info] Booting $id ..."
  xcrun simctl boot "$id" || true
  # -d 180: 180秒でタイムアウト。System App待ちでハングしない。
  if ! xcrun simctl bootstatus "$id" -b -d 180; then
    echo "[warn] bootstatus timeout for $id"
    return 1
  fi
  return 0
}
boot_and_wait "$UDID" || {
  echo "[warn] Retry after erase..."
  xcrun simctl erase "$UDID" || true
  boot_and_wait "$UDID" || { echo "[error] Simulator failed to boot"; exit 4; }
}

# --- build (DerivedData fixed) ---
DERIVED="build"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "id=$UDID" \
  -sdk iphonesimulator \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  clean build | xcpretty || true

APP_DIR="$DERIVED/Build/Products/Debug-iphonesimulator"
APP_PATH=$(ls -1 "$APP_DIR"/*.app | head -n1 || true)
[[ -z "${APP_PATH}" ]] && { echo "[error] .app not found under $APP_DIR"; exit 5; }
echo "[info] Built app: $APP_PATH"

# --- bundle id from Info.plist ---
PLIST="$APP_PATH/Info.plist"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST" 2>/dev/null || true)
echo "[info] BundleID: ${BUNDLE_ID:-<unknown>}"

# --- install & (optional) launch ---
xcrun simctl install "$UDID" "$APP_PATH" || true
if [[ -n "${BUNDLE_ID:-}" ]]; then
  xcrun simctl launch "$UDID" "$BUNDLE_ID" || echo "[warn] launch failed"
fi

# --- screenshot ---
mkdir -p artifacts/screenshots
if ! xcrun simctl io "$UDID" screenshot "artifacts/screenshots/screen.png"; then
  echo "[warn] screenshot failed; trying booted fallback"
  xcrun simctl io booted screenshot "artifacts/screenshots/screen.png" || true
fi

echo "[info] Done. See artifacts/screenshots/screen.png"

