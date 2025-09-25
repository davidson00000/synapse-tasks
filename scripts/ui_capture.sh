#!/usr/bin/env bash
set -euo pipefail

# Defaults (can be overridden via env or arguments)
SCHEME=${SCHEME:-SynapseTasks}
PROJECT=${PROJECT:-SynapseTasks.xcodeproj}
DERIVED_DATA=${DERIVED:-$PWD/build/ci-derived}
SCREENSHOT=""
UDID=""
BUNDLE_ID=""
APP_PATH=""
RUNTIME=${RUNTIME:-}
DEVTYPE=${DEVTYPE:-}

print_usage() {
    cat <<'USAGE'
Usage: scripts/ui_capture.sh [options]
  --scheme <name>
  --project <path>
  --derived-data <path>
  --udid <simulator-udid>
  --bundle-id <bundle-id>
  --app-path <path-to-app>
  --screenshot <output-path> (required)
  --runtime <runtime-id>
  --devtype <device-type-id>
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scheme)
            SCHEME="$2"; shift 2 ;;
        --project)
            PROJECT="$2"; shift 2 ;;
        --derived-data)
            DERIVED_DATA="$2"; shift 2 ;;
        --udid)
            UDID="$2"; shift 2 ;;
        --bundle-id)
            BUNDLE_ID="$2"; shift 2 ;;
        --app-path)
            APP_PATH="$2"; shift 2 ;;
        --screenshot)
            SCREENSHOT="$2"; shift 2 ;;
        --runtime)
            RUNTIME="$2"; shift 2 ;;
        --devtype)
            DEVTYPE="$2"; shift 2 ;;
        -h|--help)
            print_usage; exit 0 ;;
        *)
            echo "[warn] Unknown argument: $1" >&2; shift ;;
    esac
done

if [[ -z "$SCREENSHOT" ]]; then
    echo "[error] --screenshot is required" >&2
    print_usage
    exit 1
fi

mkdir -p "$(dirname "$SCREENSHOT")"

resolve_runtime() {
    if [[ -n "$RUNTIME" ]]; then
        echo "$RUNTIME"
        return
    fi
    xcrun simctl list runtimes --json | python3 - <<'PY'
import json, sys
runtimes = json.load(sys.stdin).get("runtimes", [])
# Prefer iOS 18.*, fallback to latest available iOS runtime
preferred = None
fallback = None
for rt in runtimes:
    if not rt.get("isAvailable", False):
        continue
    identifier = rt.get("identifier", "")
    if identifier.startswith("com.apple.CoreSimulator.SimRuntime.iOS-18"):
        if preferred is None:
            preferred = identifier
    if identifier.startswith("com.apple.CoreSimulator.SimRuntime.iOS"):
        fallback = identifier if fallback is None else fallback
print(preferred or fallback or "", end="")
PY
}

resolve_devtype() {
    if [[ -n "$DEVTYPE" ]]; then
        echo "$DEVTYPE"
        return
    fi
    xcrun simctl list devicetypes --json | python3 - <<'PY'
import json, sys
for dt in json.load(sys.stdin).get("devicetypes", [])[::-1]:
    name = dt.get("name", "")
    identifier = dt.get("identifier", "")
    if "iPhone 15" in name:
        print(identifier, end="")
        break
PY
}

create_simulator_if_needed() {
    if [[ -n "$UDID" ]]; then
        echo "$UDID"
        return
    fi
    local runtime
    runtime=$(resolve_runtime)
    if [[ -z "$runtime" ]]; then
        echo "[error] Unable to resolve simulator runtime" >&2
        exit 1
    fi
    RUNTIME="$runtime"
    local devtype
    devtype=$(resolve_devtype)
    if [[ -z "$devtype" ]]; then
        echo "[error] Unable to resolve simulator device type" >&2
        exit 1
    fi
    DEVTYPE="$devtype"
    local name="CI-Temp-$(date +%s)"
    local sim_udid
    sim_udid=$(xcrun simctl create "$name" "$DEVTYPE" "$RUNTIME")
    echo "$sim_udid"
}

UDID=$(create_simulator_if_needed)
echo "[info] Using simulator: $UDID" >&2

cleanup() {
    if [[ ${KEEP_SIMULATOR:-0} -eq 0 ]]; then
        xcrun simctl shutdown "$UDID" 2>/dev/null || true
        xcrun simctl delete "$UDID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

retry() {
    local attempts=$1
    shift
    local count=0
    until "$@"; do
        count=$((count + 1))
        if [[ $count -ge $attempts ]]; then
            return 1
        fi
        sleep 2
    done
    return 0
}

boot_simulator() {
    xcrun simctl boot "$UDID" 2>/dev/null || true
    retry 5 xcrun simctl bootstatus "$UDID" -b
}

boot_simulator

# Attempt to derive BUNDLE_ID if not supplied
if [[ -z "$BUNDLE_ID" ]]; then
    BUILD_SETTINGS=$(xcodebuild -showBuildSettings \
        -scheme "$SCHEME" \
        ${PROJECT:+-project "$PROJECT"} \
        -sdk iphonesimulator \
        -configuration Debug 2>/dev/null)
    BUNDLE_ID=$(echo "$BUILD_SETTINGS" | awk -F ' = ' '/PRODUCT_BUNDLE_IDENTIFIER/ {print $2; exit}')
fi

if [[ -z "$BUNDLE_ID" ]]; then
    echo "[error] Unable to determine bundle identifier" >&2
    exit 1
fi

echo "[info] Bundle ID: $BUNDLE_ID" >&2

if [[ -z "$APP_PATH" ]]; then
    APP_PATH=$(find "$DERIVED_DATA/Build/Products" -type d -name "*.app" -print -quit 2>/dev/null || true)
fi

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
    echo "[error] Unable to locate .app inside $DERIVED_DATA/Build/Products" >&2
    exit 1
fi

echo "[info] App path: $APP_PATH" >&2

retry 3 xcrun simctl install "$UDID" "$APP_PATH"

TAB=${TASKS_SCREENSHOT_TAB:-board}
WEEKDAY=${TASKS_SELECTED_WEEKDAY:-mon}
echo "[info] Launch env TASKS_SCREENSHOT_TAB=$TAB TASKS_SELECTED_WEEKDAY=$WEEKDAY" >&2

retry 3 xcrun simctl launch --terminate-running-process --console-pty \
    --env TASKS_SCREENSHOT_TAB="$TAB" \
    --env TASKS_SELECTED_WEEKDAY="$WEEKDAY" \
    "$UDID" "$BUNDLE_ID" >/tmp/ci_launch.log || true

sleep 5

y=0
until xcrun simctl io "$UDID" screenshot "$SCREENSHOT"; do
    y=$((y + 1))
    if [[ $y -ge 3 ]]; then
        echo "[error] Failed to capture screenshot after retries" >&2
        exit 1
    fi
    echo "[warn] Screenshot attempt $y failed, retrying..." >&2
    sleep 3
    xcrun simctl launch --terminate-running-process --console-pty \
        --env TASKS_SCREENSHOT_TAB="$TAB" \
        --env TASKS_SELECTED_WEEKDAY="$WEEKDAY" \
        "$UDID" "$BUNDLE_ID" >/tmp/ci_launch.log || true
    sleep 5
end

echo "[info] Screenshot saved to $SCREENSHOT" >&2
```
