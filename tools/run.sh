#!/usr/bin/env bash
set -euo pipefail

SCHEME="SynapseTasks"
BUNDLE_ID="com.kousuke.synapsetasks"
DEST_NAME="${DEST_NAME:-iPhone 15}"   # 環境変数で上書き可
CONFIG="Debug"

echo "==> Ensure Simulator is running: ${DEST_NAME}"
open -a Simulator >/dev/null 2>&1 || true
# 端末取得（なければ作成）
DEVICE_ID=$(xcrun simctl list devices | awk -v n="$DEST_NAME" -F '[()]' '$0 ~ n && $0 ~ "Booted" {print $2; exit}')
if [ -z "${DEVICE_ID:-}" ]; then
  DEVICE_ID=$(xcrun simctl list devices | awk -v n="$DEST_NAME" -F '[()]' '$0 ~ n {print $2; exit}')
  if [ -z "${DEVICE_ID:-}" ]; then
    # iOS 18系の最新ランタイムで作る（必要なら名称調整）
    RUNTIME=$(xcrun simctl list runtimes | awk -F '[()]' '/iOS 18/ {print $2; exit}')
    xcrun simctl create "$DEST_NAME" "com.apple.CoreSimulator.SimDeviceType.iPhone-15" "$RUNTIME"
    DEVICE_ID=$(xcrun simctl list devices | awk -F '[()]' '$0 ~ "iPhone 15" {print $2; exit}')
  fi
fi
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true

echo "==> Build"
xcodebuild \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath build \
  build | xcbeautify

APP="build/Build/Products/${CONFIG}-iphonesimulator/${SCHEME}.app"

echo "==> Install"
xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" || true
xcrun simctl install "$DEVICE_ID" "$APP"

echo "==> Launch"
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" || {
  echo "Launch failed. Tail logs:"
  xcrun simctl spawn "$DEVICE_ID" log stream --level debug --style compact --predicate 'process == "'"$SCHEME"'"' | head -n 200
  exit 1
}

echo "✅ Done"
