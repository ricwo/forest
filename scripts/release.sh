#!/bin/bash
set -e

VERSION=$1
if [ -z "$VERSION" ]; then
  echo "Usage: ./scripts/release.sh <version>"
  echo "Example: ./scripts/release.sh 1.0.1"
  exit 1
fi

git fetch --tags

if git rev-parse "$VERSION" >/dev/null 2>&1; then
  echo "Error: Tag $VERSION already exists"
  exit 1
fi

echo "Creating release $VERSION..."
git tag "$VERSION"
git push origin "$VERSION"

echo "Done! GitHub Actions will build and create the release."
echo "Watch progress: gh run watch"
