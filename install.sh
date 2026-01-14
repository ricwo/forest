#!/bin/bash
set -e

# Forest installer
# Usage: curl -fsSL https://raw.githubusercontent.com/ricwo/forest/main/install.sh | bash

REPO="ricwo/forest"
APP_NAME="forest.app"
INSTALL_DIR="/Applications"

echo "Installing forest..."

# Get latest release URL
DOWNLOAD_URL=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep "browser_download_url.*forest.zip" | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: Could not find latest release"
    exit 1
fi

# Create temp directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Download and extract
echo "Downloading from $DOWNLOAD_URL..."
curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/forest.zip"
unzip -q "$TMP_DIR/forest.zip" -d "$TMP_DIR"

# Remove old version if exists
if [ -d "$INSTALL_DIR/$APP_NAME" ]; then
    echo "Removing old version..."
    rm -rf "$INSTALL_DIR/$APP_NAME"
fi

# Install
echo "Installing to $INSTALL_DIR..."
mv "$TMP_DIR/$APP_NAME" "$INSTALL_DIR/"

# Remove quarantine attribute (bypass Gatekeeper for unsigned app)
xattr -cr "$INSTALL_DIR/$APP_NAME" 2>/dev/null || true

echo "Done! Run 'open /Applications/forest.app' or find forest in Spotlight."
