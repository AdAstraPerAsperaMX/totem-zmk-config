#!/bin/sh
# Builds TotemBattery.app next to this script. Requires the Xcode command line tools.
set -e
cd "$(dirname "$0")"
APP=TotemBattery.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -target arm64-apple-macos13 -o "$APP/Contents/MacOS/TotemBattery-arm64" main.swift
swiftc -O -target x86_64-apple-macos13 -o "$APP/Contents/MacOS/TotemBattery-x86_64" main.swift
lipo -create -output "$APP/Contents/MacOS/TotemBattery" "$APP/Contents/MacOS/TotemBattery-arm64" "$APP/Contents/MacOS/TotemBattery-x86_64"
rm "$APP/Contents/MacOS/TotemBattery-arm64" "$APP/Contents/MacOS/TotemBattery-x86_64"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>TotemBattery</string>
    <key>CFBundleIdentifier</key><string>local.totem.battery</string>
    <key>CFBundleExecutable</key><string>TotemBattery</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $(pwd)/$APP"
