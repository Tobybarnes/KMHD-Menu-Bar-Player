#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="KMHD-Menu-Bar-Player"
SRC="KMHD-Menu-Bar-Player"
APP="build/$APP_NAME.app"
# Info.plist is the one place the version lives; the Xcode project and README follow it.
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$SRC/Info.plist")
FRAMEWORKS=(-framework Cocoa -framework AVFoundation -framework MediaPlayer -framework Network -framework ServiceManagement)

echo "Building KMHD Menu Bar Player $VERSION..."
mkdir -p build

# Compile every Swift file, so new files never need adding here.
# Release DMGs are universal so they run on Intel and Apple silicon Macs.
if [[ "${1:-}" == "--dmg" ]]; then
    for arch in arm64 x86_64; do
        swiftc -O "$SRC"/*.swift -target "$arch-apple-macos13.0" -o "build/$APP_NAME-$arch" "${FRAMEWORKS[@]}"
    done
    lipo -create "build/$APP_NAME-arm64" "build/$APP_NAME-x86_64" -output "build/$APP_NAME"
else
    swiftc -O "$SRC"/*.swift -o "build/$APP_NAME" "${FRAMEWORKS[@]}"
fi

# Create app bundle
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "build/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$SRC/Info.plist" "$APP/Contents/Info.plist"

# Sign locally (ad hoc). Not sandboxed, so the updater can replace the app in place.
codesign --force --sign - --entitlements "$SRC/KMHD_Menu_Bar_Player.entitlements" "$APP"

if [[ "${1:-}" == "--dmg" ]]; then
    echo "Creating .dmg..."
    STAGE="build/dmg"
    rm -rf "$STAGE" "build/$APP_NAME.dmg"
    mkdir -p "$STAGE"
    cp -R "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname "KMHD Menu Bar Player" \
        -srcfolder "$STAGE" \
        -ov -format UDZO \
        "build/$APP_NAME.dmg"
    rm -rf "$STAGE"
    echo "  Distribute:   build/$APP_NAME.dmg"
fi

echo "Done!"
echo "  Run locally:  open $APP"
