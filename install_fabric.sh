#!/bin/bash

# Usage: ./install_version.sh [minecraft_version] [fabric_version]
# If no minecraft_version provided, defaults to latest release

MINECRAFT_VERSION=$1
FABRIC_VERSION=$2

APP_SUPPORT_DIR="$HOME/Library/Application Support"
MINECRAFT_DIR="$APP_SUPPORT_DIR/ReallyBadLauncher"

VERSIONS_BASE_DIR="$MINECRAFT_DIR/versions"

echo "Downloading version manifest..."
curl -s https://piston-meta.mojang.com/mc/game/version_manifest.json -o version_manifest.json

if [ -z "$MINECRAFT_VERSION" ]; then
  # Get the latest release version ID from manifest
  MINECRAFT_VERSION=$(jq -r '.latest.release' version_manifest.json)
  echo "No Minecraft version specified. Using latest release: $MINECRAFT_VERSION"
else
  echo "Using specified Minecraft version: $MINECRAFT_VERSION"
fi

if [ -n "$FABRIC_VERSION" ]; then
  echo "Fabric version specified (not used yet): $FABRIC_VERSION"
fi

# Get the URL for the specified minecraft version
VERSION_URL=$(jq -r --arg ver "$MINECRAFT_VERSION" '.versions[] | select(.id == $ver) | .url' version_manifest.json)

if [ -z "$VERSION_URL" ]; then
  echo "Version $MINECRAFT_VERSION not found in manifest."
  exit 1
fi

echo "Found version JSON URL: $VERSION_URL"

# Create version-specific directory
VERSION_DIR="$VERSIONS_BASE_DIR/$MINECRAFT_VERSION"
mkdir -p "$VERSION_DIR"

# Download the version-specific JSON named as <version>.json inside the version folder
curl -s "$VERSION_URL" -o "$VERSION_DIR/${MINECRAFT_VERSION}.json"

# Extract client.jar URL from the downloaded JSON
CLIENT_JAR_URL=$(jq -r '.downloads.client.url' "$VERSION_DIR/${MINECRAFT_VERSION}.json")

if [ -z "$CLIENT_JAR_URL" ]; then
  echo "Client jar URL not found for version $MINECRAFT_VERSION."
  exit 1
fi

echo "Downloading client jar from $CLIENT_JAR_URL ..."
curl -o "$VERSION_DIR/${MINECRAFT_VERSION}.jar" "$CLIENT_JAR_URL"

echo "Download complete: $VERSION_DIR/${MINECRAFT_VERSION}.jar"

# Directly download Fabric installer version 1.0.3
fabric_version="1.0.3"
jar_url="https://maven.fabricmc.net/net/fabricmc/fabric-installer/$fabric_version/fabric-installer-$fabric_version.jar"

echo "Downloading Fabric installer version $fabric_version from: $jar_url"

# Ensure Minecraft dir exists
mkdir -p "$MINECRAFT_DIR"

# Download the Fabric installer JAR into the Minecraft directory
curl -o "$MINECRAFT_DIR/fabric-installer-$fabric_version.jar" "$jar_url"

echo "Fabric installer downloaded to: $MINECRAFT_DIR/fabric-installer-$fabric_version.jar"

java -jar "$MINECRAFT_DIR/fabric-installer-$fabric_version.jar" client -mcversion "$MINECRAFT_VERSION" -loader "$FABRIC_VERSION" -dir "$MINECRAFT_DIR" -noprofile
