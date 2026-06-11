#!/bin/bash
# agentpad quick install — downloads the latest release into /Applications.
#   curl -fsSL https://raw.githubusercontent.com/pameziane-hub/agentpad/main/install.sh | bash
# Uses only tools that ship with macOS (curl, ditto, xattr, osascript).
set -euo pipefail

ZIP_URL="https://github.com/pameziane-hub/agentpad/releases/latest/download/agentpad.zip"
TMP_ZIP="$(mktemp -d)/agentpad.zip"
TMP_DIR="$(mktemp -d)"
APP="/Applications/agentpad.app"

echo "⬇️  Downloading the latest agentpad release…"
curl -fsSL -o "$TMP_ZIP" "$ZIP_URL"

# replace any running copy cleanly
osascript -e 'quit app "agentpad"' 2>/dev/null || true
sleep 1

ditto -x -k "$TMP_ZIP" "$TMP_DIR"
rm -rf "$APP"
ditto "$TMP_DIR/agentpad.app" "$APP"

# the release build is signed but not notarized: clearing the quarantine
# flag is what lets Gatekeeper run it without the scary dialog
xattr -cr "$APP"

rm -rf "$TMP_ZIP" "$TMP_DIR"
open "$APP"

echo ""
echo "✅ agentpad is installed and running (🎮 icon in the menu bar)."
echo ""
echo "Two things left to do, once:"
echo "  1. Grant the Accessibility permission when macOS asks:"
echo "     System Settings → Privacy & Security → Accessibility → enable agentpad"
echo "  2. Pair your Xbox controller via Bluetooth."
echo ""
echo "Press the controller's Menu button (☰) to open agentpad's menu. Have fun!"
