#!/bin/bash
#
# generate_screenshots.sh
# Generates App Store screenshots for SixFour Chess (EN, FR, IT)
#
# Prerequisite: iPhone 14 Plus simulator must exist.
# To create it (one-time):
#   xcrun simctl create "iPhone 14 Plus" \
#     com.apple.CoreSimulator.SimDeviceType.iPhone-14-Plus \
#     com.apple.CoreSimulator.SimRuntime.iOS-18-5
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

SCHEME="SixFourChessApp Dev"
DESTINATION="platform=iOS Simulator,name=iPhone 14 Plus,OS=18.5"
TEST_TARGET="SixFourChessAppUITests/ScreenshotTests"
RESULT_BUNDLE="screenshots.xcresult"
EXPORT_DIR="screenshots_export"

echo "=== SixFour Chess — App Store Screenshots ==="
echo ""

# 1. Clean previous results
echo "[1/4] Cleaning previous results..."
rm -rf "$RESULT_BUNDLE" "$EXPORT_DIR"

# 2. Run UI tests
echo "[2/4] Running screenshot tests on iPhone 14 Plus (6.5-inch screenshots)..."
echo "       This takes ~3 minutes."
echo ""
if ! xcodebuild test \
  -project SixFourChessApp.xcodeproj \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -only-testing:"$TEST_TARGET" \
  -resultBundlePath "./$RESULT_BUNDLE" \
  2>&1 | tee /tmp/sixfour_screenshots.log; then
  echo ""
  echo "Screenshot tests failed. Full log: /tmp/sixfour_screenshots.log"
  exit 1
fi

echo ""

# 3. Export attachments
echo "[3/4] Exporting screenshots..."
mkdir -p "$EXPORT_DIR"
xcrun xcresulttool export attachments \
  --path "$RESULT_BUNDLE" \
  --output-path "$EXPORT_DIR" \
  > /dev/null 2>&1

# 4. Rename files to clean names
echo "[4/4] Renaming files..."
python3 -c "
import json, os, shutil
os.chdir('$EXPORT_DIR')
with open('manifest.json') as f:
    data = json.load(f)
for test in data:
    for att in test.get('attachments', []):
        old = att['exportedFileName']
        suggested = att['suggestedHumanReadableName']
        new_name = suggested.split('_0_')[0] + '.png' if '_0_' in suggested else suggested
        if os.path.exists(old):
            shutil.move(old, new_name)
os.remove('manifest.json')
"

if ! ls "$EXPORT_DIR"/*.png >/dev/null 2>&1; then
  echo ""
  echo "No screenshots were exported."
  echo "Check the test result bundle: $SCRIPT_DIR/$RESULT_BUNDLE"
  exit 1
fi

# Summary
echo ""
echo "=== Done! 15 screenshots generated ==="
echo ""
echo "Output: $SCRIPT_DIR/$EXPORT_DIR/"
echo ""
ls -1 "$EXPORT_DIR"/*.png | while read f; do
  dims=$(sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w"x"h}')
  echo "  $(basename "$f")  ($dims)"
done
echo ""
echo "Upload these to App Store Connect under the 6.5\" display category."
