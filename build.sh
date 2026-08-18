#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_DIR="$PROJECT_DIR/QuotaMonitor.app"
CONTENTS_DIR="$APP_DIR/Contents"
ARCH="$(uname -m)"

rm -rf "$BUILD_DIR" "$APP_DIR"
mkdir -p "$BUILD_DIR" "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"

swiftc -swift-version 5 -parse-as-library \
    "$PROJECT_DIR"/Sources/*.swift \
    -o "$CONTENTS_DIR/MacOS/QuotaMonitor" \
    -framework AppKit \
    -framework Security \
    -framework SwiftUI \
    -target "$ARCH-apple-macos13.0"

swift "$PROJECT_DIR/Tools/GenerateIcon.swift" "$BUILD_DIR/AppIcon.iconset"
iconutil -c icns "$BUILD_DIR/AppIcon.iconset" -o "$CONTENTS_DIR/Resources/AppIcon.icns"
cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

codesign --force --deep --sign - "$APP_DIR"
echo "Built $APP_DIR"
