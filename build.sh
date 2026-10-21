#!/bin/sh
set -e
cd "$(dirname "$0")"
mkdir -p Clippy.app/Contents/MacOS
swiftc -O -swift-version 6 Sources/main.swift -o Clippy.app/Contents/MacOS/Clippy
cp Info.plist Clippy.app/Contents/Info.plist
# icon: swift assets/svg2icns.swift assets/icon.svg /tmp/Clippy.iconset && iconutil -c icns /tmp/Clippy.iconset -o assets/Clippy.icns
mkdir -p Clippy.app/Contents/Resources
cp assets/Clippy.icns Clippy.app/Contents/Resources/
# shortcut: ad-hoc signature changes each build, so Login Items may need re-toggling; use a Developer ID if that gets annoying
codesign --force --sign - Clippy.app
codesign --verify --strict Clippy.app
# Launch at Login records the bundle path, so run it from a stable location, not this folder
pkill -x Clippy || true
rm -rf /Applications/Clippy.app
cp -R Clippy.app /Applications/Clippy.app
echo "Installed. Launch from /Applications/Clippy.app (not the repo copy), then enable Launch at Login."
