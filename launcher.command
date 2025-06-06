#!/bin/bash

pip3 install -r requirements.txt

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

xattr -rc "$SCRIPT_DIR/create_minecraft_directory.sh"
xattr -rc "$SCRIPT_DIR/download_vanilla.sh"
xattr -rc "$SCRIPT_DIR/fabric.command"
xattr -rc "$SCRIPT_DIR/install_fabric.sh"

$SCRIPT_DIR/create_minecraft_directory.sh

python3 "$SCRIPT_DIR/new_launcher.py"
