#!/bin/bash
# Builds PortMonitor-X.Y.Z.dmg installer.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="PortMonitor"
VERSION="${1:-1.0.0}"
DMG_NAME="$APP_NAME-$VERSION.dmg"
STAGING="dmg-staging"

# Ensure .app is up to date.
./build-app.sh

echo "→ DMG-Staging vorbereiten…"
rm -rf "$STAGING" "$DMG_NAME"
mkdir -p "$STAGING"
cp -R "$APP_NAME.app" "$STAGING/"

if ! command -v create-dmg >/dev/null 2>&1; then
    echo "✗ create-dmg nicht gefunden. Installiere mit: brew install create-dmg"
    exit 1
fi

echo "→ DMG erzeugen…"
create-dmg \
    --volname "$APP_NAME $VERSION" \
    --window-pos 200 120 \
    --window-size 600 320 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 150 140 \
    --app-drop-link 450 140 \
    --hide-extension "$APP_NAME.app" \
    --no-internet-enable \
    "$DMG_NAME" \
    "$STAGING/" || true

# Cleanup
rm -rf "$STAGING"

if [ -f "$DMG_NAME" ]; then
    SIZE=$(du -h "$DMG_NAME" | cut -f1)
    echo ""
    echo "✓ Fertig: $(pwd)/$DMG_NAME ($SIZE)"
else
    echo "✗ DMG wurde nicht erzeugt"
    exit 1
fi
