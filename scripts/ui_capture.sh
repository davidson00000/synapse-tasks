#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-SynapseTasks.xcodeproj}"
SCHEME="${SCHEME:-SynapseTasks}"
# OSを書かなくても最新に当たるようにし、必要ならYAML側で上書きできる
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 16}"

echo "[info] Project    : $PROJECT"
echo "[info] Scheme     : $SCHEME"
echo "[info] Destination: $DESTINATION"

# スキーム存在チェック（読めなければログを出して即落とす）
if ! xcodebuild -list -project "$PROJECT" | grep -A20 "Schemes:" | grep -q "^[[:space:]]*$SCHEME$"; then
  echo "Error: Scheme '$SCHEME' not found in $PROJECT" >&2
  xcodebuild -list -project "$PROJECT" || true
  exit 2
fi

# ビルド
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -sdk iphonesimulator \
  -destination "$DESTINATION" \
  build

# TODO: ここに UI スクショ処理を追加
echo "[info] Build completed, add screenshot commands here."

