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
  MINECRAFT_VERSION=$(python3 -c "import json; print(json.load(open('version_manifest.json'))['latest']['release'])")
  echo "No Minecraft version specified. Using latest release: $MINECRAFT_VERSION"
else
  echo "Using specified Minecraft version: $MINECRAFT_VERSION"
fi

if [ -n "$FABRIC_VERSION" ]; then
  echo "Fabric version specified (not used yet): $FABRIC_VERSION"
fi

# Get the URL for the specified Minecraft version using Python
VERSION_URL=$(python3 -c "
import json
with open('version_manifest.json') as f:
    versions = json.load(f)['versions']
    print(next(v['url'] for v in versions if v['id'] == '$MINECRAFT_VERSION'), end='')
")

if [ -z "$VERSION_URL" ]; then
  echo "Version $MINECRAFT_VERSION not found in manifest."
  exit 1
fi

echo "Found version JSON URL: $VERSION_URL"

# Create version-specific directory
VERSION_DIR="$VERSIONS_BASE_DIR/$MINECRAFT_VERSION"
mkdir -p "$VERSION_DIR"

# Download the version-specific JSON
curl -s "$VERSION_URL" -o "$VERSION_DIR/${MINECRAFT_VERSION}.json"

# Extract client.jar URL from version JSON using Python
CLIENT_JAR_URL=$(python3 -c "
import json
with open('$VERSION_DIR/${MINECRAFT_VERSION}.json') as f:
    print(json.load(f)['downloads']['client']['url'], end='')
")

if [ -z "$CLIENT_JAR_URL" ]; then
  echo "Client jar URL not found for version $MINECRAFT_VERSION."
  exit 1
fi

echo "Downloading client jar from $CLIENT_JAR_URL ..."
curl -o "$VERSION_DIR/${MINECRAFT_VERSION}.jar" "$CLIENT_JAR_URL"
echo "Download complete: $VERSION_DIR/${MINECRAFT_VERSION}.jar"

# Download Fabric installer
fabric_version="1.0.3"
jar_url="https://maven.fabricmc.net/net/fabricmc/fabric-installer/$fabric_version/fabric-installer-$fabric_version.jar"
echo "Downloading Fabric installer version $fabric_version from: $jar_url"

mkdir -p "$MINECRAFT_DIR"
curl -o "$MINECRAFT_DIR/fabric-installer-$fabric_version.jar" "$jar_url"
echo "Fabric installer downloaded to: $MINECRAFT_DIR/fabric-installer-$fabric_version.jar"

java -jar "$MINECRAFT_DIR/fabric-installer-$fabric_version.jar" client -mcversion "$MINECRAFT_VERSION" -loader "$FABRIC_VERSION" -dir "$MINECRAFT_DIR" -noprofile
