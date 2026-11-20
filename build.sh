#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="KMHD-Menu-Bar-Player"
SRC="KMHD-Menu-Bar-Player"
APP="build/$APP_NAME.app"
# Info.plist is the one place the version lives; the Xcode project and README follow it.
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$SRC/Info.plist")

echo "Building KMHD Menu Bar Player $VERSION..."

# Compile every Swift file, so new files never need adding here
mkdir -p build
swiftc -O "$SRC"/*.swift \
    -o "build/$APP_NAME" \
    -framework Cocoa \
    -framework AVFoundation \
    -framework MediaPlayer \
    -framework Network \
    -framework ServiceManagement

# Create app bundle
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "build/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$SRC/Info.plist" "$APP/Contents/Info.plist"

# Sign locally (ad hoc) with the app's entitlements: sandboxed, network only
codesign --force --sign - --entitlements "$SRC/KMHD_Menu_Bar_Player.entitlements" "$APP"

if [[ "${1:-}" == "--dmg" ]]; then
    echo "Creating .dmg..."
    rm -f "build/$APP_NAME.dmg"
    hdiutil create -volname "KMHD Menu Bar Player" \
        -srcfolder "$APP" \
        -ov -format UDZO \
        "build/$APP_NAME.dmg"
    echo "  Distribute:   build/$APP_NAME.dmg"
fi

echo "Done!"
echo "  Run locally:  open $APP"
