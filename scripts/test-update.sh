#!/bin/bash
set -e

# Test the full update flow end-to-end
# This simulates what UpdateService.swift does

echo "=== Forest Update Flow Test ==="
echo ""

# Setup
TMP_DIR=$(mktemp -d)
DMG_PATH="$TMP_DIR/forest.dmg"
SCRIPT_PATH="$TMP_DIR/update.sh"
TEST_INSTALL_DIR="$TMP_DIR/Applications"
mkdir -p "$TEST_INSTALL_DIR"

# Create a fake "old" app to replace
mkdir -p "$TEST_INSTALL_DIR/forest.app/Contents"
echo "old version" > "$TEST_INSTALL_DIR/forest.app/Contents/old.txt"

cleanup() {
    echo ""
    echo "==> Cleaning up..."
    hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Step 1: Get latest release URL
echo "==> Step 1: Fetching latest release info..."
DOWNLOAD_URL=$(curl -fsSL "https://api.github.com/repos/ricwo/forest/releases/latest" | grep "browser_download_url.*forest.dmg" | cut -d '"' -f 4)
echo "    URL: $DOWNLOAD_URL"

if [ -z "$DOWNLOAD_URL" ]; then
    echo "FAILED: Could not get download URL"
    exit 1
fi

# Step 2: Download DMG
echo ""
echo "==> Step 2: Downloading DMG..."
curl -fsSL "$DOWNLOAD_URL" -o "$DMG_PATH"
echo "    Downloaded to: $DMG_PATH"
echo "    Size: $(du -h "$DMG_PATH" | cut -f1)"

# Step 3: Create and run update script (same as UpdateService.swift)
echo ""
echo "==> Step 3: Creating update script..."

cat > "$SCRIPT_PATH" << 'SCRIPT'
#!/bin/bash
DMG_PATH="__DMG_PATH__"
INSTALL_DIR="__INSTALL_DIR__"

# Mount DMG (no -quiet, we need the output to find mount point)
MOUNT_DIR=$(hdiutil attach "$DMG_PATH" -nobrowse 2>/dev/null | grep "/Volumes" | sed 's/.*\(\/Volumes\/.*\)/\1/')

if [ -z "$MOUNT_DIR" ]; then
    echo "FAILED: Could not mount DMG"
    exit 1
fi
echo "    Mounted at: $MOUNT_DIR"

# Check app exists
if [ ! -d "$MOUNT_DIR/forest.app" ]; then
    echo "FAILED: forest.app not found in DMG"
    hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null
    exit 1
fi

# Replace app
echo "    Removing old app..."
rm -rf "$INSTALL_DIR/forest.app"

echo "    Copying new app..."
cp -R "$MOUNT_DIR/forest.app" "$INSTALL_DIR/"

# Cleanup
echo "    Unmounting..."
hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null
xattr -cr "$INSTALL_DIR/forest.app" 2>/dev/null || true

echo "    Done!"
SCRIPT

# Replace placeholders
sed -i '' "s|__DMG_PATH__|$DMG_PATH|g" "$SCRIPT_PATH"
sed -i '' "s|__INSTALL_DIR__|$TEST_INSTALL_DIR|g" "$SCRIPT_PATH"

echo "==> Step 4: Running update script..."
bash "$SCRIPT_PATH"

# Step 5: Verify
echo ""
echo "==> Step 5: Verifying installation..."

if [ ! -d "$TEST_INSTALL_DIR/forest.app" ]; then
    echo "FAILED: forest.app not found after update"
    exit 1
fi

if [ -f "$TEST_INSTALL_DIR/forest.app/Contents/old.txt" ]; then
    echo "FAILED: Old app content still present"
    exit 1
fi

if [ ! -f "$TEST_INSTALL_DIR/forest.app/Contents/MacOS/forest" ]; then
    echo "FAILED: New app binary not found"
    exit 1
fi

# Get version from new app
NEW_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$TEST_INSTALL_DIR/forest.app/Contents/Info.plist" 2>/dev/null || echo "unknown")
echo "    Installed version: $NEW_VERSION"

echo ""
echo "=== SUCCESS: Update flow works correctly! ==="
