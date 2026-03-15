#!/bin/zsh
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP_NAME="ScreenPath"
VERSION="0.4"
BUILD="4"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
ZIP_PATH="$DIST_DIR/${APP_NAME}.app.zip"
DMG_PATH="$DIST_DIR/${APP_NAME}.dmg"
DMG_STAGING="$DIST_DIR/dmg-root"
RESOURCE_BUNDLE="$ROOT/.build/arm64-apple-macosx/release/ScreenPath_ScreenPath.bundle"
ICON_FILE="$ROOT/Assets/ScreenPath.icns"

cd "$ROOT"
swift build -c release

rm -rf "$APP_DIR" "$ZIP_PATH" "$DMG_PATH" "$DMG_STAGING"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$ROOT/.build/release/ScreenPath" "$APP_DIR/Contents/MacOS/ScreenPath"
cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"
cp "$ICON_FILE" "$APP_DIR/Contents/Resources/ScreenPath.icns"
chmod +x "$APP_DIR/Contents/MacOS/ScreenPath"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>com.ekwinder.screenpath</string>
  <key>CFBundleVersion</key>
  <string>${BUILD}</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>ScreenPath</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

mkdir -p "$DMG_STAGING"
cp -R "$APP_DIR" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH" >/dev/null

printf '\nZIP SHA256\n'
shasum -a 256 "$ZIP_PATH"
printf '\nDMG SHA256\n'
shasum -a 256 "$DMG_PATH"
