#!/bin/bash
set -e

echo "Building KMHD Menu Bar Player..."

# Compile
mkdir -p build
swiftc KMHD-Menu-Bar-Player/main.swift \
    KMHD-Menu-Bar-Player/AppDelegate.swift \
    KMHD-Menu-Bar-Player/AboutWindowController.swift \
    KMHD-Menu-Bar-Player/UpdateChecker.swift \
    KMHD-Menu-Bar-Player/SettingsWindowController.swift \
    -o build/KMHD-Menu-Bar-Player \
    -framework Cocoa \
    -framework WebKit \
    -framework Network \
    -framework ServiceManagement

# Create app bundle
mkdir -p "build/KMHD-Menu-Bar-Player.app/Contents/MacOS" \
         "build/KMHD-Menu-Bar-Player.app/Contents/Resources"
cp build/KMHD-Menu-Bar-Player "build/KMHD-Menu-Bar-Player.app/Contents/MacOS/KMHD-Menu-Bar-Player"
cp KMHD-Menu-Bar-Player/Info.plist "build/KMHD-Menu-Bar-Player.app/Contents/Info.plist"

# Copy icon resource if present
if [ -f "KMHD-Menu-Bar-Player/Resources/kmhd-icon.png" ]; then
    cp "KMHD-Menu-Bar-Player/Resources/kmhd-icon.png" "build/KMHD-Menu-Bar-Player.app/Contents/Resources/"
fi

# Create .dmg for distribution
echo "Creating .dmg..."
rm -f build/KMHD-Menu-Bar-Player.dmg
hdiutil create -volname "KMHD Menu Bar Player" \
    -srcfolder build/KMHD-Menu-Bar-Player.app \
    -ov -format UDZO \
    build/KMHD-Menu-Bar-Player.dmg

echo "Done!"
echo "  Run locally:  open build/KMHD-Menu-Bar-Player.app"
echo "  Distribute:   build/KMHD-Menu-Bar-Player.dmg"
