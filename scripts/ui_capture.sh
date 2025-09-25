#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-SynapseTasks.xcodeproj}"
SCHEME="${SCHEME:-SynapseTasks}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 16}"

echo "[info] Project    : $PROJECT"
echo "[info] Scheme     : $SCHEME"
echo "[info] Destination: $DESTINATION"

# スキーム存在チェック
if ! xcodebuild -list -project "$PROJECT" | grep -A20 "Schemes:" | grep -q "^[[:space:]]*$SCHEME$"; then
  echo "Error: Scheme '$SCHEME' not found in $PROJECT" >&2
  xcodebuild -list -project "$PROJECT" || true
  exit 2
fi

# DerivedDataを固定して .app の場所を分かりやすく
DERIVED="build"
APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/${SCHEME}.app"

# クリーン＆ビルド
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -sdk iphonesimulator \
  -destination "$DESTINATION" \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  clean build

# ★（任意）最低限のスクショ処理。起動なしのホーム画面でもOK。
# もしアプリのバンドルIDが分かれば、install & launchに切り替えてください。
mkdir -p artifacts/screenshots

# シミュレータ起動（存在しなければ起動）
BOOTED_ID=$(xcrun simctl list devices | awk -v d="$DESTINATION" '
  BEGIN{split(d,a,","); for(i in a){ if (a[i] ~ /name=/){sub("name=","",a[i]); target=a[i]}}}
  /Booted/ && index($0,target){match($0,/\(([A-F0-9-]+)\)/,m); print m[1]}
')
if [ -z "${BOOTED_ID:-}" ]; then
  # 最初にnameだけ取り出す
  NAME=$(echo "$DESTINATION" | sed -n 's/.*name=\([^,]*\).*/\1/p')
  BOOTED_ID=$(xcrun simctl list devices | grep "$NAME (" | head -n1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
  [ -n "$BOOTED_ID" ] && xcrun simctl boot "$BOOTED_ID" || true
fi

# とりあえずホーム画面のスクショ（失敗してもCIは落とさない）
xcrun simctl io booted screenshot "artifacts/screenshots/home.png" || echo "[warn] screenshot skipped"

echo "[info] Build completed. Screenshots (if any) are in artifacts/screenshots"

