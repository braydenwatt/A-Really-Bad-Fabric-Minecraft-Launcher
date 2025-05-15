#!/bin/bash

# Usage: ./install_version.sh [version]
# If no version provided, defaults to latest release

VERSION=$1

APP_SUPPORT_DIR="$HOME/Library/Application Support"
MINECRAFT_DIR="$APP_SUPPORT_DIR/ReallyBadLauncher"

VERSIONS_BASE_DIR="$MINECRAFT_DIR/versions"

echo "Downloading version manifest..."
curl -s https://piston-meta.mojang.com/mc/game/version_manifest.json -o version_manifest.json

if [ -z "$VERSION" ]; then
  # Get the latest release version ID from manifest using Python
  VERSION=$(python3 -c "import json; print(json.load(open('version_manifest.json'))['latest']['release'])")
  echo "No version specified. Using latest release: $VERSION"
else
  echo "Using specified version: $VERSION"
fi

# Get the URL for the specified version using Python
VERSION_URL=$(python3 -c "
import json
with open('version_manifest.json') as f:
    data = json.load(f)
    print(next(v['url'] for v in data['versions'] if v['id'] == '$VERSION'), end='')
")

if [ -z "$VERSION_URL" ]; then
  echo "Version $VERSION not found in manifest."
  exit 1
fi

echo "Found version JSON URL: $VERSION_URL"

# Create version-specific directory
VERSION_DIR="$VERSIONS_BASE_DIR/$VERSION"
mkdir -p "$VERSION_DIR"

# Download the version-specific JSON named as <version>.json inside the version folder
curl -s "$VERSION_URL" -o "$VERSION_DIR/${VERSION}.json"

# Extract client.jar URL from the downloaded JSON using Python
CLIENT_JAR_URL=$(python3 -c "
import json
with open('$VERSION_DIR/${VERSION}.json') as f:
    print(json.load(f)['downloads']['client']['url'], end='')
")

if [ -z "$CLIENT_JAR_URL" ]; then
  echo "Client jar URL not found for version $VERSION."
  exit 1
fi

echo "Downloading client jar from $CLIENT_JAR_URL ..."
curl -o "$VERSION_DIR/${VERSION}.jar" "$CLIENT_JAR_URL"

echo "Download complete: $VERSION_DIR/${VERSION}.jar"
