#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-SynapseTasks.xcodeproj}"
SCHEME="${SCHEME:-SynapseTasks}"
# 未指定でも動く。name 指定がなければ自動で最新 iPhone を選ぶ
DESTINATION="${DESTINATION:-}"

echo "[info] Project : $PROJECT"
echo "[info] Scheme  : $SCHEME"
echo "[info] Destenv : ${DESTINATION:-<auto>}"

# --- スキーム存在チェック ---
if ! xcodebuild -list -project "$PROJECT" | awk '/Schemes:/,0' | grep -q -E "^[[:space:]]+$SCHEME$"; then
  echo "[error] Scheme '$SCHEME' not found in $PROJECT" >&2
  xcodebuild -list -project "$PROJECT" || true
  exit 2
fi

# --- デバイス自動解決（name 未指定なら最新の iPhone） ---
if [[ -z "${DESTINATION}" ]]; then
  # 一番新しい "iPhone " デバイスのうち、起動可能なものを選択
  CANDIDATE=$(xcrun simctl list devices available | \
              grep -E "iPhone [0-9]+" | \
              tail -n1 | \
              sed -E 's/^[[:space:]]*([^()]+) .*/\1/')
  if [[ -z "${CANDIDATE}" ]]; then
    echo "[warn] No iPhone simulator found; falling back to generic"
    DESTINATION="platform=iOS Simulator,name=iPhone 15"
  else
    DESTINATION="platform=iOS Simulator,name=${CANDIDATE}"
  fi
fi
echo "[info] Destination resolved to: $DESTINATION"

# --- ビルド（派生ディレクトリ固定） ---
DERIVED="build"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -sdk iphonesimulator \
  -destination "$DESTINATION" \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  clean build | xcpretty || true

APP_DIR="$DERIVED/Build/Products/Debug-iphonesimulator"
APP_PATH=$(ls -1 "$APP_DIR"/*.app | head -n1 || true)
if [[ -z "${APP_PATH}" ]]; then
  echo "[error] .app not found under $APP_DIR" >&2
  exit 3
fi
echo "[info] Built app: $APP_PATH"

# --- シミュレータの UDID を取得して起動 ---
NAME=$(echo "$DESTINATION" | sed -n 's/.*name=\([^,]*\).*/\1/p')
UDID=$(xcrun simctl list devices available | grep "$NAME (" | tail -n1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
if [[ -z "${UDID}" ]]; then
  echo "[error] Could not resolve UDID for simulator '$NAME'" >&2
  xcrun simctl list devices
  exit 4
fi

# Boot if needed
xcrun simctl bootstatus "$UDID" -b || xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b

# --- Bundle ID を Info.plist から取得 ---
PLIST="$APP_PATH/Info.plist"
if [[ ! -f "$PLIST" ]]; then
  echo "[warn] Info.plist not found; skipping launch"
else
  BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST" 2>/dev/null || true)
  echo "[info] BundleID: ${BUNDLE_ID:-<unknown>}"
fi

# --- インストール＆（分かれば）起動 ---
xcrun simctl install "$UDID" "$APP_PATH" || true
if [[ -n "${BUNDLE_ID:-}" ]]; then
  xcrun simctl launch "$UDID" "$BUNDLE_ID" || echo "[warn] launch failed; taking home screenshot instead"
fi

# --- スクリーンショット ---
mkdir -p artifacts/screenshots
xcrun simctl io "$UDID" screenshot "artifacts/screenshots/screen.png" || {
  echo "[warn] screenshot failed; trying booted fallback"
  xcrun simctl io booted screenshot "artifacts/screenshots/screen.png" || true
}

echo "[info] Done. Screenshots under artifacts/screenshots"
