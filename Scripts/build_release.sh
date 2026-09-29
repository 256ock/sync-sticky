#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme StickyNotes -configuration Release \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGN_IDENTITY="-" \
  clean build

APP_PATH=".build/DerivedData/Build/Products/Release/StickyNotes.app"
DIST_DIR="dist"
DIST_APP_PATH="$DIST_DIR/StickyNotes.app"

mkdir -p "$DIST_DIR"
rm -rf "$DIST_APP_PATH"
ditto "$APP_PATH" "$DIST_APP_PATH"

echo ""
echo "Built: $DIST_APP_PATH"
codesign --verify --deep --strict --verbose=2 "$DIST_APP_PATH"
codesign -dv "$DIST_APP_PATH" 2>&1
