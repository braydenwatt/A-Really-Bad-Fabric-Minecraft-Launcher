#!/bin/bash

if [ "$#" -lt 6 ]; then
  echo "Usage: $0 <USERNAME> <UUID> <PROFILE_NAME> <MC_VERSION> <FABRIC_VERSION> <ACCESS_TOKEN> [JAVA_PATH]"
  exit 1
fi

USERNAME="$1"
UUID="$2"
PROFILE_NAME="$3"
MC_VERSION="$4"
FABRIC_VERSION="$5"
ACCESS_TOKEN="$6"
JAVA_PATH="$7"

VERSION="${MC_VERSION}-${FABRIC_VERSION}"

MODRINTH_DIR="$HOME/Library/Application Support/com.modrinth.theseus"
GAME_DIR="$MODRINTH_DIR/profiles/$PROFILE_NAME"
VERSION_DIR="$MODRINTH_DIR/meta/versions/$VERSION"
VERSION_JSON="$VERSION_DIR/$VERSION.json"
ASSETS_DIR="$MODRINTH_DIR/meta/assets"
NATIVES_DIR="$MODRINTH_DIR/meta/natives/${VERSION}"
LIBRARIES_DIR="$MODRINTH_DIR/meta/libraries"

# Check if VERSION_JSON exists
if [ ! -f "$VERSION_JSON" ]; then
  echo "❌ Version JSON file not found at: $VERSION_JSON"
  exit 1
fi

mkdir -p "$NATIVES_DIR"

echo "Building classpath..."

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

CLASSPATH=""

# 🔁 Python replacement for jq logic
LIBRARIES=$(python3 -c "
import json
data = json.load(open('$VERSION_JSON'))
os_name = '$CURRENT_OS'
libs = []
for lib in data.get('libraries', []):
    if not lib.get('include_in_classpath') or not lib.get('downloadable'):
        continue
    rules = lib.get('rules')
    if rules:
        if not any(rule.get('action') == 'allow' and rule.get('os', {}).get('name') == os_name for rule in rules):
            continue
    downloads = lib.get('downloads', {})
    if 'artifact' in downloads and 'path' in downloads['artifact']:
        libs.append(downloads['artifact']['path'])
    elif 'name' in lib and ':' in lib['name']:
        group, artifact, version = lib['name'].split(':')
        group_path = group.replace('.', '/')
        libs.append(f'{group_path}/{artifact}/{version}/{artifact}-{version}.jar')
print('\n'.join(libs))
")

while IFS= read -r library_path; do
  full_path="$LIBRARIES_DIR/$library_path"
  if [ -f "$full_path" ]; then
    CLASSPATH="$CLASSPATH:$full_path"
  else
    echo "⚠️ Missing library: $full_path"
  fi
done <<< "$LIBRARIES"

MC_CLIENT_JAR="$VERSION_DIR/$VERSION.jar"
if [ -f "$MC_CLIENT_JAR" ]; then
  CLASSPATH="$CLASSPATH:$MC_CLIENT_JAR"
else
  echo "⚠️ Minecraft client JAR not found at: $MC_CLIENT_JAR"
fi

FABRIC_LOADER="$LIBRARIES_DIR/net/fabricmc/fabric-loader/${FABRIC_VERSION}/fabric-loader-${FABRIC_VERSION}.jar"

if [ -f "$FABRIC_LOADER" ]; then
  CLASSPATH="$CLASSPATH:$FABRIC_LOADER"
else
  echo "⚠️ Fabric Loader not found at: $FABRIC_LOADER"
fi

if [[ -z "$CLASSPATH" ]]; then
  echo "❌ Classpath is empty. Could not find any libraries."
  exit 1
fi

CLASSPATH="${CLASSPATH#:}"

CLASSPATH_FILE="$GAME_DIR/classpath.txt"
echo "Writing classpath to $CLASSPATH_FILE..."
echo "Classpath built with $(echo "$CLASSPATH" | awk -F: '{print NF}') elements" > "$CLASSPATH_FILE"
echo "$CLASSPATH" >> "$CLASSPATH_FILE"
echo "✅ Classpath written to $CLASSPATH_FILE"

# 🔁 Extract mainClass and assetIndex via Python too
read MAIN_CLASS ASSET_INDEX < <(python3 -c "
import json
with open('$VERSION_JSON') as f:
    j = json.load(f)
main = j.get('mainClass', 'net.fabricmc.loader.impl.launch.knot.KnotClient')
asset = j.get('assetIndex', {}).get('id', '1.21')
print(main, asset)
")

# Java path logic remains unchanged
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

"$JAVA_PATH/bin/java" \
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
  -Dorg.lwjgl.util.Debug=true \
  -Dorg.lwjgl.util.DebugLoader=true \
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
