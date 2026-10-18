#!/bin/sh
# App icon + App Store header/search art, all from the shared dove geometry.
set -eu
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
swiftc -O Packages/PrayerLockKit/Sources/PLBrand/DoveGeometry.swift scripts/app-icon/main.swift -o "$TMP/art"
"$TMP/art" icon App/PrayerLock/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
mkdir -p docs/brand
"$TMP/art" header docs/brand/AppStore-Header-3840x1646.png
"$TMP/art" search docs/brand/AppStore-SearchResult-1920x1280.png
