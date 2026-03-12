#!/bin/bash
set -e

APP_NAME="ClaudeCodeMonitor"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
SIGNING_IDENTITY="ClaudeCodeMonitor Signing"

echo "==> Building release..."
swift build -c release

echo "==> Preparing app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp .build/arm64-apple-macosx/release/$APP_NAME "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp assets/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "==> Signing with: $SIGNING_IDENTITY"
codesign --force --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"

echo "==> Verifying signature..."
codesign -dvv "$APP_BUNDLE" 2>&1 | grep -E "Authority|Signature"

echo ""
echo "==> Done! App bundle: $APP_BUNDLE"
echo "    Run: open $APP_BUNDLE"
