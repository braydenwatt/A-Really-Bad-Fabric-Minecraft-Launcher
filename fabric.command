#!/bin/bash

if [ "$#" -lt 5 ]; then
  echo "Usage: $0 <USERNAME> <UUID> <PROFILE_NAME> <VERSION> <ACCESS_TOKEN>"
  exit 1
fi

USERNAME="$1"
UUID="$2"
PROFILE_NAME="$3"
VERSION="$4"
ACCESS_TOKEN="$5"

MODRINTH_DIR="$HOME/Library/Application Support/com.modrinth.theseus"
GAME_DIR="$MODRINTH_DIR/profiles/$PROFILE_NAME"
VERSION_DIR="$MODRINTH_DIR/meta/versions/$VERSION"
VERSION_JSON="$VERSION_DIR/$VERSION.json"
ASSETS_DIR="$MODRINTH_DIR/meta/assets"
NATIVES_DIR="$VERSION_DIR/natives"
LIBRARIES_DIR="$MODRINTH_DIR/meta/libraries"


# Check if VERSION_JSON exists
if [ ! -f "$VERSION_JSON" ]; then
  echo "❌ Version JSON file not found at: $VERSION_JSON"
  exit 1
fi

# Create natives directory if it doesn't exist
mkdir -p "$NATIVES_DIR"

echo "Building classpath..."

# Determine current OS
UNAME=$(uname -s)
ARCH=$(uname -m)
if [[ "$UNAME" == "Darwin" ]]; then
  CURRENT_OS="osx"
  [[ "$ARCH" == "arm64" ]] && CURRENT_OS="osx-arm64"
elif [[ "$UNAME" == "Linux" ]]; then
  CURRENT_OS="linux"
else
  CURRENT_OS="windows"
fi

# Initialize empty classpath
CLASSPATH=""

# Build library paths using both download path and fallback from name
LIBRARIES=$(jq -r --arg os "$CURRENT_OS" '
  .libraries[]
  | select(.include_in_classpath == true and .downloadable == true)
  | select(
      (has("rules") | not)
      or
      (.rules | map(select(.action == "allow" and .os.name == $os)) | length > 0)
    )
  | if has("downloads") and .downloads.artifact.path then
      .downloads.artifact.path
    elif has("url") and (.name | test("^.+:.+:.+$")) then
      .name as $name |
      ($name | split(":")) as [$group, $artifact, $version] |
      ($group | gsub("\\."; "/")) as $group_path |
      "\($group_path)/\($artifact)/\($version)/\($artifact)-\($version).jar"
    else
      empty
    end
' "$VERSION_JSON")

# Append libraries to classpath
while IFS= read -r library_path; do
  full_path="$LIBRARIES_DIR/$library_path"
  if [ -f "$full_path" ]; then
    CLASSPATH="$CLASSPATH:$full_path"
  else
    echo "⚠️ Missing library: $full_path"
  fi
done <<< "$LIBRARIES"

# Add Minecraft client JAR
MC_CLIENT_JAR="$VERSION_DIR/$VERSION.jar"
if [ -f "$MC_CLIENT_JAR" ]; then
  CLASSPATH="$CLASSPATH:$MC_CLIENT_JAR"
else
  echo "⚠️ Minecraft client JAR not found at: $MC_CLIENT_JAR"
fi

# Add Fabric Loader JAR
FABRIC_LOADER="$LIBRARIES_DIR/net/fabricmc/fabric-loader/0.16.10/fabric-loader-0.16.10.jar"
if [ -f "$FABRIC_LOADER" ]; then
  CLASSPATH="$CLASSPATH:$FABRIC_LOADER"
else
  echo "⚠️ Fabric Loader not found at: $FABRIC_LOADER"
fi

# Check if classpath is empty
if [[ -z "$CLASSPATH" ]]; then
  echo "❌ Classpath is empty. Could not find any libraries."
  exit 1
fi

# Remove leading colon
CLASSPATH="${CLASSPATH#:}"

# Write classpath to file
CLASSPATH_FILE="$GAME_DIR/classpath.txt"
echo "Writing classpath to $CLASSPATH_FILE..."
echo "Classpath built with $(echo "$CLASSPATH" | awk -F: '{print NF}') elements" > "$CLASSPATH_FILE"
echo "$CLASSPATH" >> "$CLASSPATH_FILE"
echo "✅ Classpath written to $CLASSPATH_FILE"

# Extract values from JSON
MAIN_CLASS=$(jq -r '.mainClass // "net.fabricmc.loader.impl.launch.knot.KnotClient"' "$VERSION_JSON")
ASSET_INDEX=$(jq -r '.assetIndex.id // "1.21"' "$VERSION_JSON")

JAVA_PATH="$6"

if [ -z "$JAVA_PATH" ]; then
  JAVA_PATH=$(/usr/libexec/java_home -v 21 2>/dev/null)
  if [ -z "$JAVA_PATH" ]; then
    echo "❌ Java 21 installation not found. Please provide a valid JAVA_PATH."
    exit 1
  fi
  echo "🔍 Using auto-detected Java 21 at: $JAVA_PATH"
else
  if [ ! -x "$JAVA_PATH/bin/java" ]; then
    echo "❌ Provided JAVA_PATH is invalid or Java binary not found at: $JAVA_PATH/bin/java"
    exit 1
  fi
  echo "✅ Using provided Java path: $JAVA_PATH"
fi

"$JAVA_HOME/bin/java" \
  -XstartOnFirstThread \
  -Xmx2G \
  -Xms512M \
  -XX:+UseG1GC \
  -XX:+ParallelRefProcEnabled \
  -XX:+UnlockExperimentalVMOptions \
  -Djava.library.path="$NATIVES_DIR" \
  -Djna.tmpdir="$NATIVES_DIR" \
  -Dorg.lwjgl.system.SharedLibraryExtractPath="$NATIVES_DIR" \
  -Dio.netty.native.workdir="$NATIVES_DIR" \
  -Dminecraft.launcher.brand="Modrinth" \
  -Dminecraft.launcher.version="1.0" \
  -Dmixin.java.compatibilityLevel=JAVA_21 \
  -Dmixin.env.disableCompatibilityLevel=true \
  -cp "$CLASSPATH" \
  "$MAIN_CLASS" \
  -DFabricMcEmu= net.minecraft.client.main.Main \
  --username "$USERNAME" \
  --version "$VERSION" \
  --gameDir "$GAME_DIR" \
  --assetsDir "$ASSETS_DIR" \
  --assetIndex "$ASSET_INDEX" \
  --xuid 0 \
  --userType msa \
  --uuid "$UUID" \
  --accessToken "$ACCESS_TOKEN" \
  --width 854 \
  --height 480 \
  --versionType release
