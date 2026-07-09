#!/bin/sh
# Builds the app and runs it as a proper .app bundle via `open`, instead of
# `swift run`'s raw unbundled executable. Running unbundled skips LaunchServices
# registration, which breaks SwiftUI TextField keyboard input, copy/paste, and
# other text-input-system-dependent interactions — this script exists purely to
# work around that; it has no effect on app data (Keychain/profiles.json paths
# don't depend on bundling).
set -e

cd "$(dirname "$0")/.."

APP_NAME="openfortivpn-gui"

# `open` on an already-running app just activates it rather than relaunching —
# kill any existing instance first so this always runs the freshly-built code.
pkill -x "$APP_NAME" 2>/dev/null || true

swift build

BIN_PATH=".build/debug/${APP_NAME}"
APP_BUNDLE=".build/${APP_NAME}.app"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.liyancen.openfortivpn-gui</string>
    <key>CFBundleName</key>
    <string>openfortivpn-gui</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

open "$APP_BUNDLE"
