#!/bin/sh
# Visual QA: walks every main screen in light and dark on a simulator, exports named PNGs
# and contact sheets. Not a behavioural test (see ScreenshotTourTests).
#   sh scripts/screenshot-tour.sh OUTPUT_DIR [SIMULATOR_NAME]
set -eu
cd "$(dirname "$0")/.."
OUT="${1:?usage: screenshot-tour.sh OUTPUT_DIR [SIMULATOR_NAME]}"
SIM="${2:-iPhone 17}"
rm -rf "$OUT" "$OUT.xcresult"
mkdir -p "$OUT"
TEST_RUNNER_PL_SCREENSHOT_TOUR=1 xcodebuild test -project PrayerLock.xcodeproj -scheme PrayerLock \
  -destination "platform=iOS Simulator,name=$SIM" -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO \
  -resultBundlePath "$OUT.xcresult" -only-testing:PrayerLockUITests/ScreenshotTourTests 2>&1 \
  | grep -E "passed \(|failed \(|error: |\*\* TEST" || true
xcrun xcresulttool export attachments --path "$OUT.xcresult" --output-path "$OUT/raw" >/dev/null
python3 - "$OUT" <<'PY'
import json, os, shutil, sys
out = sys.argv[1]; raw = os.path.join(out, "raw")
for test in json.load(open(os.path.join(raw, "manifest.json"))):
    for a in test["attachments"]:
        name = a.get("suggestedHumanReadableName", "")
        if name.startswith(("light", "dark")) and a["exportedFileName"].endswith(".png"):
            shutil.copy(os.path.join(raw, a["exportedFileName"]), os.path.join(out, name.split("_0_")[0].replace(" ", "-") + ".png"))
PY
for mode in light dark; do
  set -- "$OUT"/$mode-*.png
  [ -e "$1" ] && python3 scripts/contact_sheet.py "$OUT/sheet-$mode.png" "$@" --cols 6 --width 260
done
ls "$OUT"
