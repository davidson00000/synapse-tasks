#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-SynapseTasks.xcodeproj}"
SCHEME="${SCHEME:-SynapseTasks}"

echo "[info] Project: $PROJECT"
echo "[info] Scheme : $SCHEME"

# スキームが存在するか軽く検証
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
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
  build

# TODO: ここに UI キャプチャ処理を追加
echo "[info] Build completed, add screenshot commands here."

