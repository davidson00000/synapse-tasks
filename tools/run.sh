#!/usr/bin/env bash
set -euo pipefail
DEV=9B6C7E23-EB17-4B7E-95B1-FBEC6EFAB03C
xcrun simctl boot "$DEV" || true
xcrun simctl bootstatus "$DEV" -b
xcodebuild -scheme SynapseTasks -destination "platform=iOS Simulator,OS=latest,id=$DEV" -configuration Debug -derivedDataPath build build
APP=build/Build/Products/Debug-iphonesimulator/SynapseTasks.app
BID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")
xcrun simctl uninstall "$DEV" "$BID" || true
xcrun simctl install "$DEV" "$APP"
xcrun simctl launch "$DEV" "$BID"
