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
  # Get the latest release version ID from manifest
  VERSION=$(jq -r '.latest.release' version_manifest.json)
  echo "No version specified. Using latest release: $VERSION"
else
  echo "Using specified version: $VERSION"
fi

# Get the URL for the specified version
VERSION_URL=$(jq -r --arg ver "$VERSION" '.versions[] | select(.id == $ver) | .url' version_manifest.json)

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

# Extract client.jar URL from the downloaded JSON
CLIENT_JAR_URL=$(jq -r '.downloads.client.url' "$VERSION_DIR/${VERSION}.json")

if [ -z "$CLIENT_JAR_URL" ]; then
  echo "Client jar URL not found for version $VERSION."
  exit 1
fi

echo "Downloading client jar from $CLIENT_JAR_URL ..."
curl -o "$VERSION_DIR/${VERSION}.jar" "$CLIENT_JAR_URL"

echo "Download complete: $VERSION_DIR/${VERSION}.jar"
