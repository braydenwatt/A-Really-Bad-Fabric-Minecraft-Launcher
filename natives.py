import os
import json
import zipfile
import requests

from urllib.parse import urlsplit

# --- CONFIG ---
MC_VERSION = "1.21.5"
FABRIC_VERSION = "0.16.12"
VERSION = f"{MC_VERSION}-{FABRIC_VERSION}"

# Base Modrinth directory (on macOS, as per your paths)
MODRINTH_DIR = os.path.expanduser("~") + "/Library/Application Support/com.modrinth.theseus"
PROFILE_NAME = "Fabulously Optimized (6)pi"  # Replace with your actual profile name

# Define all the directories based on your structure
GAME_DIR = os.path.join(MODRINTH_DIR, "profiles", PROFILE_NAME)
VERSION_DIR = os.path.join(MODRINTH_DIR, "meta", "versions", VERSION)
VERSION_JSON = os.path.join(VERSION_DIR, f"{VERSION}.json")
ASSETS_DIR = os.path.join(MODRINTH_DIR, "meta", "assets")
NATIVES_DIR = os.path.join(MODRINTH_DIR, "meta", "natives", VERSION)
LIBRARIES_DIR = os.path.join(MODRINTH_DIR, "meta", "libraries")

os.makedirs(NATIVES_DIR, exist_ok=True)

# --- Helpers ---
def download_file(url, dest_path):
    if os.path.exists(dest_path):
        print(f"{dest_path} already exists. Skipping download.")
        return
    print(f"Downloading {url} -> {dest_path}")
    r = requests.get(url)
    r.raise_for_status()
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    with open(dest_path, 'wb') as f:
        f.write(r.content)

def extract_natives(jar_path, target_dir):
    """Extract native files from a jar file to the target directory."""
    with zipfile.ZipFile(jar_path, 'r') as zipf:
        for file in zipf.namelist():
            if file.endswith((".dll", ".so", ".dylib")):
                print(f"  Extracting {file}")
                zipf.extract(file, target_dir)

# --- Load Version JSON ---
with open(VERSION_JSON, 'r') as f:
    version_data = json.load(f)

libraries = version_data.get("libraries", [])

# --- Process Libraries ---
for lib in libraries:
    downloads = lib.get("downloads", {})
    classifiers = downloads.get("classifiers", {})
    
    native_url = None
    native_dest = None

    # Look for OS-specific natives (we're assuming macOS here, change as needed)
    for key in ["natives-macos", "natives-linux", "natives-windows"]:
        if key in lib.get("name", ""):  # Look for the right native name in library name
            classifier_key = f"{lib['name']}:{key}"  # Construct classifier name
            native_data = classifiers.get(classifier_key)
            if native_data:
                native_url = native_data["url"]
                path = native_data["path"]
                native_dest = os.path.join(LIBRARIES_DIR, path)
                break

    if native_url and native_dest:
        try:
            # Download the native jar
            download_file(native_url, native_dest)
            # Extract native files
            extract_natives(native_dest, NATIVES_DIR)
        except Exception as e:
            print(f"  Failed to process {native_url}: {e}")
