#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="SpotifyLyrics"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building $APP_NAME..."

# Clean previous build
rm -rf "$BUILD_DIR"

# Create .app bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Info.plist
cp Resources/Info.plist "$APP_BUNDLE/Contents/"

# Compile Swift sources
swiftc \
    -swift-version 5 \
    -target arm64-apple-macosx12.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -O \
    -module-name "$APP_NAME" \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    Sources/Models.swift \
    Sources/SpotifyBridge.swift \
    Sources/SpotifyLyricsAPI.swift \
    Sources/LyricsSyncEngine.swift \
    Sources/OverlaySettings.swift \
    Sources/OverlayPanel.swift \
    Sources/LyricsOverlayView.swift \
    Sources/PreferencesView.swift \
    Sources/AppDelegate.swift \
    Sources/main.swift

echo "Build successful!"
echo "App bundle: $APP_BUNDLE"
echo ""
echo "To run: open $APP_BUNDLE"
echo "Or:     $APP_BUNDLE/Contents/MacOS/$APP_NAME"
