#!/bin/bash
set -e

echo "Building KMHD Widget..."

# Compile
mkdir -p build
swiftc KMHD-Widget/main.swift KMHD-Widget/AppDelegate.swift \
    -o build/KMHD-Widget \
    -framework Cocoa \
    -framework WebKit

# Create app bundle
mkdir -p "build/KMHD-Widget.app/Contents/MacOS" \
         "build/KMHD-Widget.app/Contents/Resources"
cp build/KMHD-Widget "build/KMHD-Widget.app/Contents/MacOS/KMHD-Widget"
cp KMHD-Widget/Info.plist "build/KMHD-Widget.app/Contents/Info.plist"

echo "Done! Run with: open build/KMHD-Widget.app"
