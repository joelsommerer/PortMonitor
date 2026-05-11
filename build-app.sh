#!/bin/bash
# Builds PortMonitor.app — a menu-bar-only macOS app bundle.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="PortMonitor"
BUNDLE_ID="ch.joelsommerer.portmonitor"
VERSION="1.0.0"
APP_BUNDLE="$APP_NAME.app"

echo "→ Release build…"
swift build -c release

echo "→ App-Bundle anlegen…"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>Port Monitor</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© $(date +%Y) Joel Sommerer</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "→ Ad-hoc-signieren…"
codesign --force --deep --sign - "$APP_BUNDLE" 2>&1 | sed 's/^/   /'

echo ""
echo "✓ Fertig: $(pwd)/$APP_BUNDLE"
echo ""
echo "Starten:    open $APP_BUNDLE"
echo "Installieren: mv $APP_BUNDLE /Applications/"
