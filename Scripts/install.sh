#!/bin/sh
# Builds a release binary, packages it as a real .app bundle (with icon), and
# installs it to /Applications so it behaves like a normal Mac app afterwards
# (Launchpad/Spotlight/Dock, double-click to open) instead of needing
# Scripts/run.sh every time. /Applications is group-writable by `admin` on a
# stock Mac, so this doesn't need sudo for a normal admin account.
set -e

cd "$(dirname "$0")/.."

APP_NAME="openfortivpn-gui"
APP_BUNDLE="/Applications/${APP_NAME}.app"

pkill -x "$APP_NAME" 2>/dev/null || true

swift build -c release

BIN_PATH=".build/release/${APP_NAME}"
RESOURCE_BUNDLE=".build/release/${APP_NAME}_${APP_NAME}.bundle"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
cp "Resources/AppIcon/icon.icns" "$APP_BUNDLE/Contents/Resources/icon.icns"
# Carries the compiled Localizable.strings (en + zh-Hant) that Text()/L(...)
# calls resolve through Bundle.module at runtime — without this, the app
# falls back to the untranslated (Chinese) source strings in every locale.
cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"

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
    <key>CFBundleIconFile</key>
    <string>icon.icns</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh-Hant</string>
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

echo "Installed to $APP_BUNDLE"
open "$APP_BUNDLE"
