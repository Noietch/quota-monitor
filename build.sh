#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_DIR="$PROJECT_DIR/QuotaMonitor.app"
CONTENTS_DIR="$APP_DIR/Contents"

rm -rf "$BUILD_DIR" "$APP_DIR"
mkdir -p "$BUILD_DIR" "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"

for TARGET_ARCH in arm64 x86_64; do
    swiftc -swift-version 5 -O -parse-as-library \
        "$PROJECT_DIR"/Sources/*.swift \
        -o "$BUILD_DIR/QuotaMonitor-$TARGET_ARCH" \
        -framework AppKit \
        -framework Security \
        -framework SwiftUI \
        -target "$TARGET_ARCH-apple-macos13.0"
done

lipo -create \
    "$BUILD_DIR/QuotaMonitor-arm64" \
    "$BUILD_DIR/QuotaMonitor-x86_64" \
    -output "$CONTENTS_DIR/MacOS/QuotaMonitor"

swift "$PROJECT_DIR/Tools/GenerateIcon.swift" "$BUILD_DIR/AppIcon.iconset"
iconutil -c icns "$BUILD_DIR/AppIcon.iconset" -o "$CONTENTS_DIR/Resources/AppIcon.icns"
cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

codesign --force --deep --sign - "$APP_DIR"
echo "Built $APP_DIR"
