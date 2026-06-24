#!/usr/bin/env bash
set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────
DISPLAY_NAME="OpenPasteMac"
APP_NAME="OpenPasteMac"
BUNDLE_ID="com.xfajarr.openpastemac"
VERSION="0.1.2"
MIN_MACOS="13.0"

# ─── Paths ───────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_PATH/Contents"

cd "$ROOT_DIR"

echo "▸ Building release binary..."
swift build -c release

echo "▸ Locating binary..."
# Detect the actual binary regardless of the SPM target name
# Use -L to follow the .build/release symlink on macOS
BINARY=$(find -L .build/release -maxdepth 1 -type f -perm +111 \
  ! -name "*.dylib" ! -name "*.a" ! -name "*.product" \
  | grep -iE "(OpenPasteMac|OpenPaste|OpenClip)" | head -1)
if [ -z "$BINARY" ]; then
  # Fallback: any non-library executable
  BINARY=$(find -L .build/release -maxdepth 1 -type f -perm +111 \
    ! -name "*.dylib" ! -name "*.a" ! -name "*.product" | head -1)
fi
echo "  Using binary: $BINARY"

echo "▸ Assembling .app bundle..."
rm -rf "$APP_PATH"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

# Copy binary (renamed to the canonical APP_NAME)
cp "$BINARY" "$CONTENTS/MacOS/$APP_NAME"

# ─── Info.plist ──────────────────────────────────────────────────────────────
cat > "$CONTENTS/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>${DISPLAY_NAME} needs accessibility access to automatically paste items into other apps when you select them.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>${DISPLAY_NAME} uses Apple Events to manage clipboard content.</string>
</dict>
</plist>
PLIST

# ─── PkgInfo ─────────────────────────────────────────────────────────────────
printf "APPL????" > "$CONTENTS/PkgInfo"

echo ""
echo "✓ Built: $APP_PATH"
echo ""
echo "Next steps:"
echo "  Install to Applications:  cp -r \"$APP_PATH\" /Applications/"
echo "  Create DMG:               ./scripts/create-dmg.sh"
echo ""
echo "  To enable Launch at Login after installing:"
echo "  Right-click the menu bar icon → Launch at Login"
