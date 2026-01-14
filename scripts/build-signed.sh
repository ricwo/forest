#!/bin/bash
set -e

# Load environment
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo "Error: .env file not found. Copy .env.example to .env and fill in values."
    exit 1
fi

# Validate required vars
for var in APPLE_ID APPLE_APP_PASSWORD APPLE_TEAM_ID DEVELOPER_ID; do
    if [ -z "${!var}" ]; then
        echo "Error: $var not set in .env"
        exit 1
    fi
done

BUILD_DIR="build"
APP_NAME="forest.app"
DMG_NAME="forest.dmg"

echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Building archive..."
xcodebuild -scheme forest -configuration Release \
    -archivePath "$BUILD_DIR/forest.xcarchive" archive -quiet

echo "==> Copying app..."
cp -R "$BUILD_DIR/forest.xcarchive/Products/Applications/$APP_NAME" "$BUILD_DIR/"

echo "==> Signing app..."
codesign --force --options runtime --sign "$DEVELOPER_ID" "$BUILD_DIR/$APP_NAME"

echo "==> Creating DMG..."
hdiutil create -volname "forest" -srcfolder "$BUILD_DIR/$APP_NAME" \
    -ov -format UDZO "$BUILD_DIR/$DMG_NAME"

echo "==> Signing DMG..."
codesign --force --sign "$DEVELOPER_ID" "$BUILD_DIR/$DMG_NAME"

echo "==> Notarizing (this takes 1-5 minutes)..."
xcrun notarytool submit "$BUILD_DIR/$DMG_NAME" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait

echo "==> Stapling ticket..."
xcrun stapler staple "$BUILD_DIR/$DMG_NAME"

echo "==> Verifying..."
spctl --assess --type open --context context:primary-signature -v "$BUILD_DIR/$DMG_NAME"

echo ""
echo "==> Done! Signed DMG at: $BUILD_DIR/$DMG_NAME"
