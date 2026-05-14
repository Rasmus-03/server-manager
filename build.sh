#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
RES_DIR="$SCRIPT_DIR/Resources"
RELEASE_DIR="$SCRIPT_DIR/releases"
mkdir -p "$RELEASE_DIR"

OS="$(uname)"

if [ "$OS" = "Darwin" ]; then
  echo "=== Building macOS native app ==="
  APP_NAME="Server Manager"
  BUILD_DIR="/tmp/ServerManagerBuild"

  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR/app/Contents/MacOS"
  mkdir -p "$BUILD_DIR/app/Contents/Resources"

  xcrun swiftc \
    -o "$BUILD_DIR/app/Contents/MacOS/ServerManager" \
    -module-name ServerManager \
    -target arm64-apple-macosx14.0 \
    -O \
    "$SRC_DIR/App.swift" "$SRC_DIR/ServerManager.swift" "$SRC_DIR/ContentView.swift"

  if [ -f "$RES_DIR/AppIcon.icns" ]; then
    cp "$RES_DIR/AppIcon.icns" "$BUILD_DIR/app/Contents/Resources/"
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
  <string>2.0</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

  rm -rf "/Applications/Server Manager.app" "$RELEASE_DIR/Server Manager.app"
  cp -R "$BUILD_DIR/app" "/Applications/Server Manager.app"
  cp -R "$BUILD_DIR/app" "$RELEASE_DIR/Server Manager.app"
  echo "macOS app built: /Applications/Server Manager.app"
  echo "Archive: $RELEASE_DIR/Server Manager.app"

elif [ "$OS" = "Linux" ]; then
  echo "=== Building Linux app ==="
  echo "Checking Python dependencies..."
  if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required. Install it with: sudo apt install python3"
    exit 1
  fi

  pip3 install -r "$SRC_DIR/linux/requirements.txt" 2>/dev/null || \
    echo "Warning: Could not install PyGObject. Run: sudo apt install python3-gi python3-gi-cairo gir1.2-gtk-3.0"

  mkdir -p "$RELEASE_DIR/Server Manager"
  cp -r "$SRC_DIR/linux"/* "$RELEASE_DIR/Server Manager/"
  make -C "$SRC_DIR/linux" install PREFIX="$RELEASE_DIR/Server Manager" 2>/dev/null || true
  echo "Linux app prepared in: $RELEASE_DIR/Server Manager/"
  echo ""
  echo "To install system-wide:"
  echo "  cd src/linux && sudo make install"
  echo "  Then launch from app menu or run: server-manager"
else
  echo "Unsupported OS: $OS"
  exit 1
fi

echo ""
echo "=== Build complete ==="
echo "macOS:  /Applications/Server Manager.app"
echo "Linux:  src/linux/ (run: cd src/linux && python3 server-manager.py)"
