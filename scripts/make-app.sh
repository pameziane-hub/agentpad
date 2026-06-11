#!/bin/bash
# Builds dist/agentpad.app — a proper double-clickable menu bar app.
# A bare SPM binary dies with its terminal window and confuses macOS's
# permission system; the bundle gives agentpad its own identity.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

VERSION="$(cat VERSION)"
APP="dist/agentpad.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/agentpad "$APP/Contents/MacOS/agentpad"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>agentpad</string>
    <key>CFBundleIdentifier</key>
    <string>com.paulameziane.agentpad</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>agentpad</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>agentpad reads your game controller over Bluetooth.</string>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026 Paul Ameziane — MIT License</string>
</dict>
</plist>
PLIST

# A stable signing identity keeps the Accessibility grant across rebuilds.
# Ad-hoc fallback works but forces a re-grant after every rebuild.
SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ {print $2; exit}')}"
codesign --force --sign "${SIGN_ID:--}" "$APP"

echo "✓ Built $APP (signed: ${SIGN_ID:-ad-hoc})"
echo "  Launch:  open $APP"
echo "  Install: cp -R $APP /Applications/"
