#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

CLT_DIR="/Library/Developer/CommandLineTools"
if [[ ! -x "$CLT_DIR/usr/bin/swiftc" || ! -d "$CLT_DIR/SDKs/MacOSX.sdk" ]]; then
  echo "Xcode Command Line Tools are required. Install them with: xcode-select --install" >&2
  exit 1
fi

export DEVELOPER_DIR="$CLT_DIR"
SWIFTC="$(xcrun --find swiftc)"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

case "$(uname -m)" in
  arm64|x86_64) BUILD_ARCH="$(uname -m)" ;;
  *) echo "Unsupported build architecture: $(uname -m)" >&2; exit 1 ;;
esac

BUILD_DIR=".build/Release"
APP_PATH="$BUILD_DIR/StickyNotes.app"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/StickyNotes"
RESOURCES_PATH="$APP_PATH/Contents/Resources"
ICONSET_PATH="$BUILD_DIR/AppIcon.iconset"
ICON_PATH="$RESOURCES_PATH/AppIcon.icns"

rm -rf "$APP_PATH" "$ICONSET_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$RESOURCES_PATH" "$ICONSET_PATH"

ICON_SOURCE="StickyNotes/Assets.xcassets/AppIcon.appiconset"
cp "$ICON_SOURCE/AppIcon-16.png" "$ICONSET_PATH/icon_16x16.png"
cp "$ICON_SOURCE/AppIcon-16@2x.png" "$ICONSET_PATH/icon_16x16@2x.png"
cp "$ICON_SOURCE/AppIcon-32.png" "$ICONSET_PATH/icon_32x32.png"
cp "$ICON_SOURCE/AppIcon-32@2x.png" "$ICONSET_PATH/icon_32x32@2x.png"
cp "$ICON_SOURCE/AppIcon-128.png" "$ICONSET_PATH/icon_128x128.png"
cp "$ICON_SOURCE/AppIcon-128@2x.png" "$ICONSET_PATH/icon_128x128@2x.png"
cp "$ICON_SOURCE/AppIcon-256.png" "$ICONSET_PATH/icon_256x256.png"
cp "$ICON_SOURCE/AppIcon-256@2x.png" "$ICONSET_PATH/icon_256x256@2x.png"
cp "$ICON_SOURCE/AppIcon-512.png" "$ICONSET_PATH/icon_512x512.png"
cp "$ICON_SOURCE/AppIcon-512@2x.png" "$ICONSET_PATH/icon_512x512@2x.png"
iconutil --convert icns --output "$ICON_PATH" "$ICONSET_PATH"
rm -rf "$ICONSET_PATH"

SOURCES=()
while IFS= read -r SOURCE; do
  SOURCES+=("$SOURCE")
done < <(find StickyNotes -maxdepth 1 -name '*.swift' -print | sort)
"$SWIFTC" \
  -sdk "$SDKROOT" \
  -target "$BUILD_ARCH-apple-macosx13.0" \
  -swift-version 5 \
  -O \
  -o "$EXECUTABLE_PATH" \
  "${SOURCES[@]}"

cat > "$APP_PATH/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>StickyNotes</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.example.StickyNotes</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>StickyNotes</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"

DIST_DIR="dist"
DIST_APP_PATH="$DIST_DIR/StickyNotes.app"
mkdir -p "$DIST_DIR"
rm -rf "$DIST_APP_PATH"
ditto "$APP_PATH" "$DIST_APP_PATH"

echo "Built: $DIST_APP_PATH ($BUILD_ARCH)"
