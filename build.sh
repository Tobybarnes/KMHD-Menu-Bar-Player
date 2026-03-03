#!/bin/bash
set -e

echo "Building KMHD Widget..."

# Compile
mkdir -p build
swiftc KMHD-Widget/main.swift \
    KMHD-Widget/AppDelegate.swift \
    KMHD-Widget/AboutWindowController.swift \
    KMHD-Widget/UpdateChecker.swift \
    KMHD-Widget/SettingsWindowController.swift \
    -o build/KMHD-Widget \
    -framework Cocoa \
    -framework WebKit \
    -framework Network \
    -framework ServiceManagement

# Create app bundle
mkdir -p "build/KMHD-Widget.app/Contents/MacOS" \
         "build/KMHD-Widget.app/Contents/Resources"
cp build/KMHD-Widget "build/KMHD-Widget.app/Contents/MacOS/KMHD-Widget"
cp KMHD-Widget/Info.plist "build/KMHD-Widget.app/Contents/Info.plist"

# Copy icon resource if present
if [ -f "KMHD-Widget/Resources/kmhd-icon.png" ]; then
    cp "KMHD-Widget/Resources/kmhd-icon.png" "build/KMHD-Widget.app/Contents/Resources/"
fi

# Create .dmg for distribution
echo "Creating .dmg..."
rm -f build/KMHD-Widget.dmg
hdiutil create -volname "KMHD Widget" \
    -srcfolder build/KMHD-Widget.app \
    -ov -format UDZO \
    build/KMHD-Widget.dmg

echo "Done!"
echo "  Run locally:  open build/KMHD-Widget.app"
echo "  Distribute:   build/KMHD-Widget.dmg"
