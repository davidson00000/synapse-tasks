#!/usr/bin/env bash
set -euo pipefail

# 環境変数（引数が無くても動くようデフォルトを持つ）
SCHEME="${SCHEME:-SynapseTasks}"
DERIVED_DATA="${DERIVED_DATA:-build}"
UDID="${UDID:-}"
BUNDLE_ID="${BUNDLE_ID:-}"
APP_PATH="${APP_PATH:-}"
OUTPUT="${OUTPUT:-}"  # 無ければ後で自動決定
RUNTIME="${RUNTIME:-}"
DEVTYPE="${DEVTYPE:-}"  # 無ければ自動選定

TAB="${TASKS_SCREENSHOT_TAB:-board}"
WEEKDAY="${TASKS_SELECTED_WEEKDAY:-mon}"

usage() {
  cat >&2 <<'EOF'
Usage: scripts/ui_capture.sh [options]
  --scheme <name>                (default: $SCHEME or SynapseTasks)
  --derived-data <path>          (default: $DERIVED_DATA or build)
  --udid <simulator-udid>        (auto if not given)
  --bundle-id <bundle-id>        (auto from xcodebuild if not given)
  --app-path <path-to-app>       (auto from derived data if not given)
  --screenshot <output-path>     (default: artifacts/ui/$TAB_$WEEKDAY.png)
  --runtime <runtime-id>         (auto if not given)
  --devtype <device-type-id>     (auto: iPhone 15 or iPhone SE 3rd)
Env:
  TASKS_SCREENSHOT_TAB=[board|list|week] (default: board)
  TASKS_SELECTED_WEEKDAY=[mon|tue|wed|thu|fri|sat|sun] (default: mon)
EOF
}

# 引数パース（無くてもOK）
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme)         SCHEME="$2"; shift 2 ;;
    --derived-data)   DERIVED_DATA="$2"; shift 2 ;;
    --udid)           UDID="$2"; shift 2 ;;
    --bundle-id)      BUNDLE_ID="$2"; shift 2 ;;
    --app-path)       APP_PATH="$2"; shift 2 ;;
    --screenshot)     OUTPUT="$2"; shift 2 ;;
    --runtime)        RUNTIME="$2"; shift 2 ;;
    --devtype)        DEVTYPE="$2"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

# 出力パスの自動決定
OUTPUT="${OUTPUT:-artifacts/ui/${TAB}_${WEEKDAY}.png}"

# --- デバイス決定: UDIDが無ければ確保 ---
if [[ -z "${UDID}" ]]; then
  # 既存の iPhone デバイスを探す
  UDID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ {print $2; exit}' || true)"
  if [[ -z "${UDID}" ]]; then
    # ランタイム & デバイスタイプを自動選定
    RUNTIME="${RUNTIME:-$(xcrun simctl list runtimes | awk -F '[()]' '/iOS .* \\(/ {print $2}' | tail -n1)}"
    if xcrun simctl list devicetypes | grep -q "iPhone 15"; then
      DEVTYPE="${DEVTYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-15}"
    else
      DEVTYPE="${DEVTYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation}"
    fi
    xcrun simctl create "CI Device (auto)" "${DEVTYPE}" "${RUNTIME}" >/dev/null
    UDID="$(xcrun simctl list devices | awk -F '[()]' '/CI Device \\(auto\\)/ {print $2; exit}')"
  fi
fi

# Boot（既に起動ならOK）
xcrun simctl boot "${UDID}" || true

# --- APP_PATH が無ければビルド（CI単体実行にも対応） ---
if [[ -z "${APP_PATH}" ]]; then
  echo "[ui_capture] Building app (no APP_PATH provided)"
  xcodebuild \
    -scheme "${SCHEME}" \
    -configuration Debug \
    -destination "id=${UDID}" \
    -derivedDataPath "${DERIVED_DATA}" \
    COMPILER_INDEX_STORE_ENABLE=NO \
    ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS=NO \
    ONLY_ACTIVE_ARCH=YES \
    build | tee /tmp/ui_capture_build.log
  APP_PATH="$(find "${DERIVED_DATA}/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name '*.app' | head -n1 || true)"
fi

if [[ -z "${APP_PATH}" || ! -e "${APP_PATH}" ]]; then
  echo "[ui_capture] Error: .app not found under ${DERIVED_DATA}" >&2
  exit 70
fi

# Bundle ID 自動検出
if [[ -z "${BUNDLE_ID}" ]]; then
  BUNDLE_ID="$(xcodebuild -showBuildSettings -scheme "${SCHEME}" -configuration Debug | awk -F ' = ' '/PRODUCT_BUNDLE_IDENTIFIER/ {print $2; exit}')"
fi

# インストール
xcrun simctl install "${UDID}" "${APP_PATH}" || true

echo "[ui_capture] Launching with ENV: TAB=${TAB}, WEEKDAY=${WEEKDAY}, OUTPUT=${OUTPUT}"
xcrun simctl terminate "${UDID}" "${BUNDLE_ID}" || true
xcrun simctl launch \
  --terminate-running-app \
  --console \
  --env TASKS_SCREENSHOT_TAB="${TAB}" \
  --env TASKS_SELECTED_WEEKDAY="${WEEKDAY}" \
  "${UDID}" "${BUNDLE_ID}" || {
    echo "[ui_capture] First launch failed. Retrying after short wait..."
    sleep 3
    xcrun simctl boot "${UDID}" || true
    xcrun simctl launch \
      --terminate-running-app \
      --console \
      --env TASKS_SCREENSHOT_TAB="${TAB}" \
      --env TASKS_SELECTED_WEEKDAY="${WEEKDAY}" \
      "${UDID}" "${BUNDLE_ID}"
  }

# 安定化待ち → 撮影
mkdir -p "$(dirname "${OUTPUT}")"
sleep 6
xcrun simctl io "${UDID}" screenshot "${OUTPUT}"
echo "[ui_capture] Saved screenshot -> ${OUTPUT}"

