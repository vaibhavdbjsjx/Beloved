#!/bin/sh
# Runs every automated check that works without a device, signing or real owner values.
#   sh scripts/verify.sh            # everything
#   sh scripts/verify.sh --quick    # skip the Xcode builds
#   sh scripts/verify.sh --ui       # also run the UI tests on an iOS Simulator (slow; set
#                                   # PL_SIMULATOR to a device name, default "iPhone 17")
# Exits non-zero on the first failure. Device tests (docs/11) and signed archives are NOT
# covered here and must never be reported as passed because this script passed.
set -eu
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
step() { printf '\n== %s\n' "$1"; }

step "Swift package tests"
(cd Packages/PrayerLockKit && swift test 2>&1 | tee "$TMP/swift.log" | grep -E "Test run with|✘" || true)
if grep -q "✘" "$TMP/swift.log" || ! grep -q "Test run with" "$TMP/swift.log"; then echo "FAILED: swift test"; exit 1; fi
awk '/Test run with/ {n+=$5} END {print "total package tests passed: " n}' "$TMP/swift.log"

step "Scripture importer tests + bundled texts match pinned sources"
python3 -m unittest scripts/test_import_scripture.py
if [ -d Vendor/scripture-sources ]; then
  python3 -I scripts/import_scripture.py --check || { echo "FAILED: bundled scripture differs from a fresh import (run python3 -I scripts/import_scripture.py)"; exit 1; }
else
  echo "Vendor/scripture-sources missing: skipped freshness check (fetch with: python3 -I scripts/import_scripture.py --fetch --check)"
fi

step "Devotional library importer tests + bundled library matches pinned sources"
python3 -m unittest scripts/test_import_devotions.py
if [ -d Vendor/devotion-sources ]; then
  python3 -I scripts/import_devotions.py --check || { echo "FAILED: devotions.json differs from a fresh import (run python3 -I scripts/import_devotions.py)"; exit 1; }
else
  echo "Vendor/devotion-sources missing: skipped freshness check (fetch with: python3 -I scripts/import_devotions.py --fetch --check)"
fi

step "Companion server tests"
node --test server/companion/test/*.test.js

step "Release tooling tests"
python3 -m unittest Config/test_release_tools.py

step "Website tests"
python3 -m unittest website/test_site.py

step "Website preview build + check"
python3 website/build.py --config website/site.example.json --preview --out "$TMP/site"

step "Release content report (expected to list blocked items until content is approved)"
python3 Config/release-content-report.py || true

if [ "${1:-}" != "--quick" ]; then
  for config in Debug Release; do
    step "Xcode build ($config, unsigned, simulator)"
    xcodebuild -project PrayerLock.xcodeproj -scheme PrayerLock -configuration "$config" \
      -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build -quiet 2>&1 \
      | grep -E "error|\.swift:[0-9]+:[0-9]+: warning" && { echo "FAILED: $config build"; exit 1; } || echo "BUILD SUCCEEDED"
  done
  step "UI test bundles compile"
  xcodebuild -project PrayerLock.xcodeproj -scheme PrayerLock -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO build-for-testing -quiet 2>&1 | grep -E "error" && { echo "FAILED: build-for-testing"; exit 1; } || echo "TEST BUILD SUCCEEDED"
  step "Static analyzer (Release)"
  xcodebuild -project PrayerLock.xcodeproj -scheme PrayerLock -configuration Release \
    -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO analyze -quiet 2>&1 \
    | grep -E "error|warning: .*\.swift" && { echo "FAILED: analyze"; exit 1; } || echo "ANALYZE SUCCEEDED"
fi

if [ "${1:-}" = "--ui" ]; then
  step "UI tests on the iOS Simulator (${PL_SIMULATOR:-iPhone 17}); not evidence of Screen Time behaviour"
  xcodebuild test -project PrayerLock.xcodeproj -scheme PrayerLock \
    -destination "platform=iOS Simulator,name=${PL_SIMULATOR:-iPhone 17}" \
    -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$TMP/ui.log" | grep -E "passed \(|failed \(|error: " || true
  grep -q "\*\* TEST SUCCEEDED \*\*" "$TMP/ui.log" || { echo "FAILED: UI tests"; exit 1; }
  echo "UI TESTS SUCCEEDED"
fi

printf '\nAll automated checks passed. NOT covered: physical-device tests (docs/11), signing, archive%s.\n' \
  "$([ "${1:-}" = "--ui" ] || echo ', UI tests (run with --ui)')"
