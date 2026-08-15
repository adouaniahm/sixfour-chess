#!/bin/bash
#
# compose_store_screenshots.sh
# Creates localized App Store-ready screenshot compositions
# from the raw PNG exports in screenshots_export/.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== SixFour Chess — Store Screenshot Composition ==="
echo ""

python3 ./scripts/compose_store_screenshots.py

echo ""
echo "Output: $SCRIPT_DIR/screenshots_store_ready/"
