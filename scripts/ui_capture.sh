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

# 1) 一時シミュレータを作成して起動
UDID=$(xcrun simctl create "CI-Temp-$(date +%s)" "$DEVTYPE" "$RUNTIME")
echo "[info] Created simulator: $UDID"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b

# 2) ビルド（iphonesimulator / 同一 DerivedData を指定）
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "id=$UDID" \
  -derivedDataPath "$DERIVED" \
  build | xcpretty

# 3) .app の場所を確定 (Debug-iphonesimulator 以下を探索)
APP_PATH="$(/usr/bin/find "$DERIVED/Build/Products/Debug-iphonesimulator" -type d -name "*.app" -print -quit)"
if [ -z "${APP_PATH:-}" ] || [ ! -d "$APP_PATH" ]; then
  echo "[error] .app not found under $DERIVED/Build/Products/Debug-iphonesimulator"
  /usr/bin/find "$DERIVED/Build/Products/Debug-iphonesimulator" -maxdepth 3 -type d -name "*.app" -print || true
  exit 1
fi
echo "[info] APP_PATH: $APP_PATH"

# 4) Bundle ID 取得
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist")
echo "[info] BundleID: $BUNDLE_ID"

# 5) インストール & 起動
set +e
xcrun simctl install "$UDID" "$APP_PATH"
INSTALL_RC=$?
set -e
if [ $INSTALL_RC -ne 0 ]; then
  echo "[error] install failed (rc=$INSTALL_RC). Dumping Info.plist:"
  /usr/libexec/PlistBuddy -c "Print" "$APP_PATH/Info.plist" || true
  exit $INSTALL_RC
fi

xcrun simctl launch "$UDID" "$BUNDLE_ID" || echo "[warn] launch failed (will continue)"

# 6) スクショ（ホーム→アプリ）
sleep 2
xcrun simctl io "$UDID" screenshot "$ARTIFACTS/01_home.png"
sleep 2
xcrun simctl io "$UDID" screenshot "$ARTIFACTS/02_app_default.png"

# 7) 追加スクショ（起動引数で画面切替）
capture_with_env () {
  local name="$1"; shift
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" --args "$@"
  sleep 2
  xcrun simctl io "$UDID" screenshot "$ARTIFACTS/$name.png"
}

# ← アプリ側が対応している起動引数に合わせて調整
capture_with_env "03_list"  TASKS_SCREENSHOT_TAB=list
capture_with_env "04_board" TASKS_SCREENSHOT_TAB=board
capture_with_env "05_week"  TASKS_SCREENSHOT_TAB=week TASKS_SELECTED_WEEKDAY=thu

# 8) クリーンアップ
xcrun simctl shutdown "$UDID"
xcrun simctl delete "$UDID"
echo "[info] Screenshots -> $ARTIFACTS"
