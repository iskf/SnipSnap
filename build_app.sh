#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "🔨 Building SnipSnap in Release configuration..."
swift build -c release

APP_NAME="SnipSnap.app"
APP_DIR="$DIR/build/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Creating macOS App Bundle at $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable binary
cp .build/release/SnipSnap "$MACOS_DIR/SnipSnap"
chmod +x "$MACOS_DIR/SnipSnap"

# Copy Info.plist
cp Resources/Info.plist "$CONTENTS_DIR/Info.plist"

# Copy application icon
cp Resources/AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
cp Resources/AppIcon.png "$RESOURCES_DIR/AppIcon.png"

# Code signing with persistent developer identity to prevent repeated Screen Recording permission prompts
echo "🔏 Code signing SnipSnap.app..."
DEV_ID=$(security find-identity -p codesigning -v | grep "Apple Development" | head -n 1 | awk -F'"' '{print $2}' || true)

if [ -n "$DEV_ID" ]; then
    echo "🔑 Signing with persistent local identity: $DEV_ID"
    codesign --force --deep --sign "$DEV_ID" "$APP_DIR"
else
    echo "⚠️ No Apple Development identity found, signing with ad-hoc identity"
    codesign --force --deep --sign - "$APP_DIR"
fi

echo "✅ SnipSnap.app built and signed successfully at: $APP_DIR"
echo "🚀 You can launch it with: open $APP_DIR"
