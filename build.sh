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

echo ""
echo "==> Done! App bundle: $APP_BUNDLE"
echo "    Run: open $APP_BUNDLE"
