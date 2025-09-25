#!/usr/bin/env bash
set -euo pipefail
SCHEME="${SCHEME:-SynapseTasks}"
CONFIG="${CONFIG:-Debug}"
echo "[Resolver] scheme=$SCHEME config=$CONFIG (iphonesimulator)"
APP_PATH=$(xcodebuild -scheme "$SCHEME" -configuration "$CONFIG" -sdk iphonesimulator -showBuildSettings \
  | awk -F' = ' '/TARGET_BUILD_DIR/{t=$2}/WRAPPER_NAME/{w=$2}END{print t"/"w}')
echo "APP_PATH = $APP_PATH"
if [ -d "$APP_PATH" ]; then
  BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist" 2>/dev/null || true)
  if [ -z "$BUNDLE_ID" ]; then
    BUNDLE_ID=$(xcodebuild -scheme "$SCHEME" -configuration "$CONFIG" -sdk iphonesimulator -showBuildSettings \
      | awk -F' = ' '/^ *PRODUCT_BUNDLE_IDENTIFIER /{print $2; exit}')
  fi
  echo "BUNDLE_ID = $BUNDLE_ID"
else
  echo "WARN: App not found. Run: make build"
fi
