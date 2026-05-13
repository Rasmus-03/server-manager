#!/bin/bash
set -e

APP_NAME="Server Manager"
BUILD_DIR="/tmp/ServerManagerBuild"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
RES_DIR="$SCRIPT_DIR/Resources"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/app/Contents/MacOS"
mkdir -p "$BUILD_DIR/app/Contents/Resources"

xcrun swiftc \
  -o "$BUILD_DIR/app/Contents/MacOS/ServerManager" \
  -module-name ServerManager \
  -target arm64-apple-macosx14.0 \
  -O \
  "$SRC_DIR/App.swift" "$SRC_DIR/ServerManager.swift" "$SRC_DIR/ContentView.swift"

if [ -f "$RES_DIR/playit" ]; then
  cp "$RES_DIR/playit" "$BUILD_DIR/app/Contents/Resources/"
fi

cat > "$BUILD_DIR/app/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>ServerManager</string>
  <key>CFBundleIdentifier</key>
  <string>com.rasmus.server-manager</string>
  <key>CFBundleName</key>
  <string>Server Manager</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

RELEASE_DIR="$SCRIPT_DIR/releases"
mkdir -p "$RELEASE_DIR"
rm -rf "/Applications/Server Manager.app" "$RELEASE_DIR/Server Manager.app"
cp -R "$BUILD_DIR/app" "/Applications/Server Manager.app"
cp -R "$BUILD_DIR/app" "$RELEASE_DIR/Server Manager.app"
echo "Done: /Applications/Server Manager.app"
echo "Archive: $RELEASE_DIR/Server Manager.app"
