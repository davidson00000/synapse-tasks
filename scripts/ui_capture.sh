#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-SynapseTasks.xcodeproj}"
SCHEME="${SCHEME:-SynapseTasks}"

echo "[info] Project: $PROJECT"
echo "[info] Scheme : $SCHEME"

# スキームが存在するか軽く検証（見つからなければ即エラー）
if ! xcodebuild -list -project "$PROJECT" | grep -E "^    Schemes:" -A50 | grep -qx "        ${SCHEME}"; then
  echo "Error: Scheme '$SCHEME' not found in $PROJECT" >&2
  xcodebuild -list -project "$PROJECT" || true
  exit 2
fi

# ここから先はビルド＆キャプチャ（例）
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
  build

# …スクショ処理…

