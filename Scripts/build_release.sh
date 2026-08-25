#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme StickyNotes -configuration Release \
  -derivedDataPath .build/DerivedData clean build

APP_PATH=".build/DerivedData/Build/Products/Release/StickyNotes.app"
DIST_DIR="dist"
ZIP_PATH="$DIST_DIR/StickyNotes.zip"

mkdir -p "$DIST_DIR"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo ""
echo "Built: $ZIP_PATH"
codesign -dv "$APP_PATH" 2>&1
