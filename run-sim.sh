#!/usr/bin/env bash
set -euo pipefail

# ======= Config (override via ENV or CLI) =======
SCHEME="${SCHEME:-SynapseTasks}"
PROJECT="${PROJECT:-SynapseTasks.xcodeproj}"
CONFIG="${CONFIG:-Debug}"
UDID="${UDID:-9B6C7E23-EB17-4B7E-95B1-FBEC6EFAB03C}"

# Optional:
DEEPLINKS="${DEEPLINKS:-}"       # e.g. "synapsetasks://seed, synapsetasks://tasks/new"
APPEARANCES="${APPEARANCES:-light,dark}"  # comma list: light,dark
SLEEP_AFTER_LAUNCH="${SLEEP_AFTER_LAUNCH:-1}"  # seconds to wait before first shot
SLEEP_AFTER_DEEPLINK="${SLEEP_AFTER_DEEPLINK:-1}"

DERIVED="build"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$DERIVED/review_queue/$RUN_ID"
SS_DIR="$OUT_DIR/screens"
LOG_DIR="$OUT_DIR/logs"
META="$OUT_DIR/manifest.json"

mkdir -p "$SS_DIR" "$LOG_DIR"

# ======= Helpers =======
have() { command -v "$1" >/dev/null 2>&1; }

json_escape() {
  # Minimal JSON string escape (quotes and backslashes)
  sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

capture() {
  local name="$1" appearance="$2"
  xcrun simctl ui "$UDID" appearance "$appearance" || true
  sleep 0.5
  local file="$SS_DIR/${name}-${appearance}.png"
  xcrun simctl io "$UDID" screenshot "$file" >/dev/null
  echo "$file"
}

# ======= 1) Build =======
echo "==> Building $SCHEME ($CONFIG) for $UDID"
if have xcbeautify; then
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
    -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
    -destination "id=$UDID" -derivedDataPath "$DERIVED" build | xcbeautify
else
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
    -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
    -destination "id=$UDID" -derivedDataPath "$DERIVED" build
fi

# ======= 2) Boot simulator =======
echo "==> Booting simulator"
open -a Simulator
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b

# Stabilize status bar for consistent screenshots (time/battery; best-effort)
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiBars 3 --batteryState charged --batteryLevel 100 2>/dev/null || true

# ======= 3) Install & Launch =======
APP="$DERIVED/Build/Products/$CONFIG-iphonesimulator/$SCHEME.app"
PLIST="$APP/Info.plist"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")

echo "==> Installing $BUNDLE_ID"
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install   "$UDID" "$APP"

echo "==> Launching app"
xcrun simctl launch "$UDID" "$BUNDLE_ID" --console > "$LOG_DIR/app.log" 2>&1 &

sleep "$SLEEP_AFTER_LAUNCH"

# ======= 4) Screenshots: Home (light/dark) =======
echo "==> Capturing Home"
IFS=',' read -ra APPS <<< "$APPEARANCES"
for ap in "${APPS[@]}"; do
  capture "001-home" "$(echo "$ap" | xargs)"
done

# ======= 5) Optional deep-link flows =======
if [[ -n "$DEEPLINKS" ]]; then
  IFS=',' read -ra LINKS <<< "$DEEPLINKS"
  idx=10
  for raw in "${LINKS[@]}"; do
    link="$(echo "$raw" | xargs)"
    safe="$(echo "$link" | tr -cd '[:alnum:]._-' | cut -c1-32)"
    [[ -z "$safe" ]] && safe="scene$idx"
    echo "==> Deeplink: $link"
    xcrun simctl openurl "$UDID" "$link" || true
    sleep "$SLEEP_AFTER_DEEPLINK"
    for ap in "${APPS[@]}"; do
      num=$(printf "%03d" "$idx")
      capture "${num}-${safe}" "$(echo "$ap" | xargs)"
    done
    idx=$((idx+1))
  done
fi

# ======= 6) Manifest =======
echo "==> Writing manifest"
# Build array of screenshots
SS_LIST=()
while IFS= read -r f; do SS_LIST+=("$f"); done < <(ls -1 "$SS_DIR" | sort)

# JSON array
SS_JSON="["
for i in "${!SS_LIST[@]}"; do
  [[ $i -gt 0 ]] && SS_JSON+=","
  SS_JSON+="\"${SS_LIST[$i]}\""
done
SS_JSON+="]"

cat > "$META" <<JSON
{
  "run_id": "$RUN_ID",
  "scheme": "$SCHEME",
  "config": "$CONFIG",
  "udid": "$UDID",
  "bundle_id": "$BUNDLE_ID",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "screens_dir": "$SS_DIR",
  "log_file": "$LOG_DIR/app.log",
  "appearances": "$APPEARANCES",
  "deeplinks": "$(echo "$DEEPLINKS" | json_escape)",
  "screens": $SS_JSON
}
JSON

echo
echo "✅ Review bundle ready"
echo "🖼 Screens: $SS_DIR"
echo "📄 Log    : $LOG_DIR/app.log"
echo "🧾 Meta   : $META"
echo
echo "次の手順："
echo "1) スクショを開いてUI確認 → 気になった点をプロンプトで伝えてください"
echo "2) 例）"
echo "   修正要望:"
echo "   - タイトルを中央寄せ"
echo "   - ダークでTextFieldの境界線を追加"
echo "   - 完了タスクの文字色をもっと薄く"

