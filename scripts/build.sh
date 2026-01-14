#!/bin/bash
set -e

cd "$(dirname "$0")/.."

APP_NAME="Forest"
BUILD_DIR="build"
RELEASE_DIR="release"

echo "🌲 Building $APP_NAME..."

# Clean previous builds
rm -rf "$BUILD_DIR" "$RELEASE_DIR"
mkdir -p "$BUILD_DIR" "$RELEASE_DIR"

# Regenerate Xcode project
echo "📦 Generating Xcode project..."
xcodegen generate

# Build Release (Apple Silicon only)
echo "🔨 Compiling (arm64)..."
xcodebuild -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -destination "platform=macOS,arch=arm64" \
    -quiet \
    build

# Find the built app
APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Build failed - app not found"
    exit 1
fi

echo "✅ Build successful"

# Copy app to release folder
cp -R "$APP_PATH" "$RELEASE_DIR/"

# Create ZIP
echo "📁 Creating ZIP..."
cd "$RELEASE_DIR"
zip -r -q "$APP_NAME.zip" "$APP_NAME.app"
cd ..

# Create DMG
echo "💿 Creating DMG..."
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$RELEASE_DIR/$APP_NAME.app" \
    -ov -format UDZO \
    "$RELEASE_DIR/$APP_NAME.dmg" \
    -quiet

# Summary
echo ""
echo "🌲 $APP_NAME built successfully!"
echo ""
echo "   release/$APP_NAME.app  - Application bundle"
echo "   release/$APP_NAME.zip  - Zipped app"
echo "   release/$APP_NAME.dmg  - Disk image"
echo ""
echo "To install: drag $APP_NAME.app to /Applications"
