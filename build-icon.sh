#!/bin/bash
# Generates AppIcon.icns from icon-1024.png.
set -euo pipefail

cd "$(dirname "$0")"

SRC="icon-1024.png"
ICONSET="AppIcon.iconset"
OUT="AppIcon.icns"

if [ ! -f "$SRC" ]; then
    echo "→ icon-1024.png fehlt, generiere…"
    swift generate-icon.swift "$SRC"
fi

rm -rf "$ICONSET" "$OUT"
mkdir -p "$ICONSET"

declare -a sizes=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

for entry in "${sizes[@]}"; do
    px="${entry%%:*}"
    name="${entry##*:}"
    sips -z "$px" "$px" "$SRC" --out "$ICONSET/$name" > /dev/null
done

iconutil -c icns "$ICONSET" -o "$OUT"
rm -rf "$ICONSET"

echo "✓ $OUT ($(du -h "$OUT" | cut -f1))"
