#!/bin/bash
set -e

APP_NAME="ClaudeCodeMonitor"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DERIVED="$BUILD_DIR/DerivedData"

echo "==> Regenerating xcodeproj from project.yml..."
xcodegen generate

echo "==> Building Release..."
xcodebuild \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    build \
    | tail -3

BUILT_APP="$DERIVED/Build/Products/Release/$APP_NAME.app"
if [ ! -d "$BUILT_APP" ]; then
    echo "ERROR: Build did not produce $BUILT_APP"
    exit 1
fi

echo "==> Copying to $APP_BUNDLE..."
mkdir -p "$BUILD_DIR"
rm -rf "$APP_BUNDLE"
cp -R "$BUILT_APP" "$APP_BUNDLE"

echo "==> Verifying signatures..."
codesign --verify --deep --strict "$APP_BUNDLE"
codesign -dvv "$APP_BUNDLE" 2>&1 | grep -E "Authority|TeamIdentifier"

echo "==> Installing to /Applications..."
pkill -x "$APP_NAME" 2>/dev/null || true
rm -rf "/Applications/$APP_NAME.app"
cp -R "$APP_BUNDLE" "/Applications/$APP_NAME.app"

# pluginkit 会锁定 first-seen appex 路径，必须注销 DerivedData 路径、
# 强制注册 /Applications 版本，并重启 chronod 让 widget 加载新 appex
LSR="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSR" -u "$BUILT_APP" 2>/dev/null || true
"$LSR" -f "/Applications/$APP_NAME.app"
killall chronod 2>/dev/null || true

open "/Applications/$APP_NAME.app"

echo ""
echo "==> Done! Installed and launched /Applications/$APP_NAME.app"
