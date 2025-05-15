#!/bin/bash

if [ "$#" -lt 6 ]; then
  echo "Usage: $0 <USERNAME> <UUID> <MC_VERSION> <FABRIC_VERSION> <ACCESS_TOKEN> [JAVA_PATH]"
  exit 1
fi

USERNAME="$1"
UUID="$2"
MC_VERSION="$3"
FABRIC_VERSION="$4"
ACCESS_TOKEN="$5"
JAVA_PATH="$6"

VERSION="fabric-loader-${FABRIC_VERSION}-${MC_VERSION}"
VERSION2="fabric-loader-${FABRIC_VERSION}"

MODRINTH_DIR="$HOME/Library/Application Support/ReallyBadLauncher"
GAME_DIR="$MODRINTH_DIR"
VERSION_DIR="$MODRINTH_DIR/versions/$VERSION"
ASSETS_DIR="$MODRINTH_DIR/assets"
NATIVES_DIR="$VERSION_DIR/natives"
LIBRARIES_DIR="$MODRINTH_DIR/libraries"

# The new Fabric JSON format
FABRIC_JSON="$VERSION_DIR/$VERSION2.json"
ORIGINAL_JSON="$VERSION_DIR/$VERSION.json"

# Create necessary directories
mkdir -p "$NATIVES_DIR"

URL="https://github.com/MidCoard/MinecraftNativesDownloader/releases/download/1.1/MinecraftNativesDownloader-1.1.jar"

curl -L -o "$VERSION_DIR/file.jar" "$URL"

cd "$VERSION_DIR"

java -jar "$VERSION_DIR/file.jar"

# Move files from build directory to natives directory
SOURCE_DIR="$VERSION_DIR/build/natives/arm64"
DEST_DIR="$VERSION_DIR/natives"

if [ -d "$SOURCE_DIR" ]; then
  echo "📦 Moving files from $SOURCE_DIR to $DEST_DIR..."
  mv "$SOURCE_DIR"/* "$DEST_DIR"/ || {
    echo "❌ Failed to move files from $SOURCE_DIR to $DEST_DIR"
    exit 1
  }
  echo "✅ Files moved successfully."
else
  echo "⚠️ Source directory does not exist: $SOURCE_DIR"
fi

echo "Building classpath..."

# Get base version from Fabric JSON inheritsFrom
INHERITS_FROM=$(python3 -c "
import json
try:
    with open('$ORIGINAL_JSON', 'r') as f:
        data = json.load(f)
    print(data.get('inheritsFrom', ''))
except:
    print('')
")

download_library() {
  local lib_path="$1"
  local full_path="$LIBRARIES_DIR/$lib_path"
  local base_url="https://libraries.minecraft.net"
  local url="$base_url/$lib_path"
  mkdir -p "$(dirname "$full_path")"
  echo "⬇️ Downloading missing library: $lib_path"
  curl -fSL "$url" -o "$full_path" || {
    echo "❌ Failed to download library: $url"
    return 1
  }
  echo "✅ Downloaded $lib_path"
  return 0
}

# Parsing inheritsFrom
INHERITS_FROM=$(python3 -c "
import json
try:
    with open('$ORIGINAL_JSON', 'r') as f:
        data = json.load(f)
    print(data.get('inheritsFrom', ''))
except:
    print('')
")

if [ -n "$INHERITS_FROM" ]; then
  echo "🧩 Found inheritsFrom version: $INHERITS_FROM"
  INHERITS_VERSION_DIR="$MODRINTH_DIR/versions/$INHERITS_FROM"
  INHERITS_JSON="$INHERITS_VERSION_DIR/$INHERITS_FROM.json"
  INHERITS_CLIENT_JAR="$INHERITS_VERSION_DIR/$INHERITS_FROM.jar"
  
  if [ ! -f "$INHERITS_JSON" ]; then
    echo "❌ Inherited version JSON not found at $INHERITS_JSON"
    exit 1
  fi

  INHERITS_LIBS=$(python3 -c "
import json
try:
    with open('$INHERITS_JSON', 'r') as f:
        data = json.load(f)
    libs = []
    for lib in data.get('libraries', []):
        if 'downloads' in lib and 'artifact' in lib['downloads']:
            path = lib['downloads']['artifact']['path']
            libs.append(path)
    print('\\n'.join(libs))
except Exception:
    print('', end='')
")

  if [ -z "$CLASSPATH" ]; then
    CLASSPATH=""
  fi

  while IFS= read -r libpath; do
    fullpath="$LIBRARIES_DIR/$libpath"
    if [ -f "$fullpath" ]; then
      CLASSPATH="$CLASSPATH:$fullpath"
    else
      echo "⚠️ Missing inherited library: $fullpath"
      if download_library "$libpath"; then
        CLASSPATH="$CLASSPATH:$fullpath"
      else
        echo "❌ Could not download inherited library $libpath"
        exit 1
      fi
    fi
  done <<< "$INHERITS_LIBS"

  # Add inherited client jar (no auto-download here, usually you have it)
  if [ -f "$INHERITS_CLIENT_JAR" ]; then
    CLASSPATH="$CLASSPATH:$INHERITS_CLIENT_JAR"
  else
    echo "⚠️ Inherited client jar missing: $INHERITS_CLIENT_JAR"
  fi
else
  echo "ℹ️ No inheritsFrom found; skipping vanilla base libraries"
fi


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

# Parse the new JSON format to get libraries
LIBRARIES=$(python3 -c "
import json
import os

try:
    with open('$ORIGINAL_JSON', 'r') as f:
        data = json.load(f)
except FileNotFoundError:
    print('❌ Fabric JSON file not found at: $FABRIC_JSON')
    exit(1)
except json.JSONDecodeError:
    print('❌ Invalid JSON in Fabric file: $FABRIC_JSON')
    exit(1)

libraries = []

for lib in data.get('libraries', []):
    if 'name' in lib:
        parts = lib['name'].split(':')
        if len(parts) == 3:
            group, artifact, version = parts
            group_path = group.replace('.', '/')
            path = f'{group_path}/{artifact}/{version}/{artifact}-{version}.jar'
            libraries.append(path)


print('\\n'.join(libraries))
")

if [ $? -ne 0 ]; then
    echo "$LIBRARIES"
    exit 1
fi

while IFS= read -r library_path; do
  full_path="$LIBRARIES_DIR/$library_path"
  if [ -f "$full_path" ]; then
    CLASSPATH="$CLASSPATH:$full_path"
  else
    echo "⚠️ Missing library: $full_path"
  fi
done <<< "$LIBRARIES"

MC_CLIENT_JAR="$VERSION_DIR/$VERSION2.jar"

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

deduplicate_classpath() {
  latest_bases=()
  latest_versions=()
  latest_jars=()

  IFS=':' read -ra paths <<< "$CLASSPATH"
  for path in "${paths[@]}"; do
    filename=$(basename "$path")
    if [[ "$filename" =~ ^([a-zA-Z0-9_.-]+)-([0-9]+(\.[0-9]+)*)(\.jar)$ ]]; then
      base="${BASH_REMATCH[1]}"
      version="${BASH_REMATCH[2]}"

      found=0
      for i in "${!latest_bases[@]}"; do
        if [[ "${latest_bases[$i]}" == "$base" ]]; then
          found=1
          current="${latest_versions[$i]}"
          # Compare versions
          newer=$(printf '%s\n' "$version" "$current" | sort -V | tail -n1)
          if [[ "$newer" == "$version" ]]; then
            latest_versions[$i]="$version"
            latest_jars[$i]="$path"
          fi
          break
        fi
      done

      if [[ $found -eq 0 ]]; then
        latest_bases+=("$base")
        latest_versions+=("$version")
        latest_jars+=("$path")
      fi
    else
      # Just add unmatched files
      latest_bases+=("$filename")
      latest_versions+=("")
      latest_jars+=("$path")
    fi
  done

  CLASSPATH=$(IFS=:; echo "${latest_jars[*]}")
}


CLASSPATH="${CLASSPATH#:}"
deduplicate_classpath


CLASSPATH_FILE="$GAME_DIR/classpath.txt"
echo "Writing classpath to $CLASSPATH_FILE..."
echo "Classpath built with $(echo "$CLASSPATH" | awk -F: '{print NF}') elements" > "$CLASSPATH_FILE"
echo "$CLASSPATH" >> "$CLASSPATH_FILE"
echo "✅ Classpath written to $CLASSPATH_FILE"

# Get main class from the JSON file
MAIN_CLASS=$(python3 -c "
import json
try:
    with open('$FABRIC_JSON', 'r') as f:
        data = json.load(f)
    print(data.get('mainClass', {}).get('client', 'net.fabricmc.loader.impl.launch.knot.KnotClient'))
except:
    print('net.fabricmc.loader.impl.launch.knot.KnotClient')
")

# Check minimum Java version
MIN_JAVA_VERSION=$(python3 -c "
import json
try:
    with open('$FABRIC_JSON', 'r') as f:
        data = json.load(f)
    print(data.get('min_java_version', 8))
except:
    print(8)
")

# Java path logic
if [ -z "$JAVA_PATH" ]; then
  JAVA_PATH=$(/usr/libexec/java_home -v 21 2>/dev/null)
  if [ -z "$JAVA_PATH" ]; then
    # Try to find a Java version that meets the minimum requirement
    JAVA_PATH=$(/usr/libexec/java_home -v $MIN_JAVA_VERSION+ 2>/dev/null)
    if [ -z "$JAVA_PATH" ]; then
      echo "❌ Java $MIN_JAVA_VERSION or higher installation not found. Please provide a valid JAVA_PATH."
      exit 1
    fi
  fi
  echo "🔍 Using auto-detected Java at: $JAVA_PATH"
else
  if [ ! -x "$JAVA_PATH/bin/java" ]; then
    echo "❌ Provided JAVA_PATH is invalid or Java binary not found at: $JAVA_PATH/bin/java"
    exit 1
  fi
  echo "✅ Using provided Java path: $JAVA_PATH"
fi

# Get Java version
JAVA_VERSION=$("$JAVA_PATH/bin/java" -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F. '{print $1}')
echo "📌 Using Java version: $JAVA_VERSION"

# Verify Java version meets minimum requirement
if [ "$JAVA_VERSION" -lt "$MIN_JAVA_VERSION" ]; then
  echo "❌ Java version $JAVA_VERSION is less than required minimum version $MIN_JAVA_VERSION"
  exit 1
fi

# Additional JVM args for Java 9+
ADDITIONAL_ARGS=""
if [ "$JAVA_VERSION" -ge 9 ]; then
  ADDITIONAL_ARGS="--add-exports java.base/sun.security.util=ALL-UNNAMED --add-opens java.base/java.util.jar=ALL-UNNAMED"
fi

# Parsing inheritsFrom
ASSET_INDEX=$(python3 -c "
import json
with open('$INHERITS_JSON', 'r') as f:
    data = json.load(f)
print(data['assetIndex']['id'])
")

ASSET_INDEX_JSON_URL=$(python3 -c "
import json
with open('$INHERITS_JSON', 'r') as f:
    data = json.load(f)
print(data['assetIndex']['url'])
")

ASSETS_INDEX_JSON_PATH="$ASSETS_DIR/indexes/$ASSET_INDEX.json"
mkdir -p "$(dirname "$ASSETS_INDEX_JSON_PATH")"

echo "⬇️ Downloading asset index JSON from $ASSET_INDEX_JSON_URL ..."
curl -fSL "$ASSET_INDEX_JSON_URL" -o "$ASSETS_INDEX_JSON_PATH" || {
  echo "❌ Failed to download asset index JSON"
  exit 1
}

echo "📦 Parsing asset index JSON to download assets..."

python3 - <<EOF
import json
import os
import subprocess

ASSETS_DIR = "$ASSETS_DIR"
INDEX_JSON_PATH = "$ASSETS_INDEX_JSON_PATH"
BASE_URL = "https://resources.download.minecraft.net"

with open(INDEX_JSON_PATH, 'r') as f:
    index = json.load(f)

objects = index.get('objects', {})

for asset_name, info in objects.items():
    hash_ = info['hash']
    subdir = hash_[:2]
    asset_path = os.path.join(ASSETS_DIR, "objects", subdir, hash_)
    
    if not os.path.isfile(asset_path):
        os.makedirs(os.path.dirname(asset_path), exist_ok=True)
        url = f"{BASE_URL}/{subdir}/{hash_}"
        print(f"⬇️ Downloading asset {asset_name} -> {asset_path}")
        # Use curl to download the file
        result = subprocess.run(["curl", "-fSL", url, "-o", asset_path])
        if result.returncode != 0:
            print(f"❌ Failed to download asset {asset_name} from {url}")
EOF

echo "✅ Assets downloaded."


echo "🚀 Launching Minecraft with Fabric..."
echo "   Main class: $MAIN_CLASS"
echo "   Asset index: $ASSET_INDEX"

"$JAVA_PATH/bin/java" \
  -XstartOnFirstThread \
  -Xmx2G \
  -Xms512M \
  -XX:+UseG1GC \
  -XX:+ParallelRefProcEnabled \
  -XX:+UnlockExperimentalVMOptions \
  $ADDITIONAL_ARGS \
  -Djava.library.path="$NATIVES_DIR" \
  -Djna.tmpdir="$NATIVES_DIR" \
  -Dorg.lwjgl.system.SharedLibraryExtractPath="$NATIVES_DIR" \
  -Dio.netty.native.workdir="$NATIVES_DIR" \
  -Dminecraft.launcher.brand="Modrinth" \
  -Dminecraft.launcher.version="1.0" \
  -Dmixin.java.compatibilityLevel=JAVA_$JAVA_VERSION \
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