#!/usr/bin/env bash
set -euo pipefail

echo ">>> Create iOS 26 simulator device"

RUNTIME=$(xcrun simctl list runtimes | awk '/iOS 26/{print $NF; exit}')
[ -z "${RUNTIME:-}" ] && { echo "ERROR: iOS 26 runtime not found."; exit 1; }
echo "Runtime: $RUNTIME"

# iPhone 系のデバイスタイプを優先して1つ取得
DTYPE=$(xcrun simctl list devicetypes | awk -F'[()]' '/iPhone/{print $2; exit}')
[ -z "${DTYPE:-}" ] && { echo "ERROR: iPhone device type not found."; exit 1; }
echo "DeviceType: $DTYPE"

DEVNAME="Synapse Runner (iOS26)"
UDID=$(xcrun simctl create "$DEVNAME" "$DTYPE" "$RUNTIME")
echo "Created: $DEVNAME -> $UDID"

echo "Booting..."
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b

echo "Open Simulator.app"
open -a Simulator --args -CurrentDeviceUDID "$UDID" || true

echo "Export this UDID to build/test/uishot:"
echo "  export UDID=$UDID"


