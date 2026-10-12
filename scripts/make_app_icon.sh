#!/bin/sh
# Builds the app icon from the same dove geometry the app and shield draw.
#   sh scripts/make_app_icon.sh [OUT.png]
set -eu
cd "$(dirname "$0")/.."
OUT="${1:-App/PrayerLock/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
swiftc -O Packages/PrayerLockKit/Sources/PLBrand/DoveGeometry.swift scripts/app-icon/main.swift -o "$TMP/make-icon"
"$TMP/make-icon" "$OUT"
