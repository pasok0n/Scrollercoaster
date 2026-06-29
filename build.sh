#!/bin/bash
set -e

swift build -c release

APP="Scrollercoaster.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp .build/release/Scrollercoaster "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"

if [ -f AppIcon.icns ]; then
    mkdir -p "$APP/Contents/Resources"
    cp AppIcon.icns "$APP/Contents/Resources/"
fi

codesign --force --deep --sign - "$APP"

echo "Built $APP"
echo "Run with: open $APP"
