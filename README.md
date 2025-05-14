# Fabric Minecraft Launcher

A lightweight Python-based launcher for running a custom `minecraft_launcher.py` and accompanying `.command` script—ideal for setting up modded Minecraft (e.g., Fabric) with a double-clickable experience on macOS.

## Requirements

* Python 3.7+
* macOS (for `.command` integration)
* `minecraft_launcher.py` and `fabric.command` must be in the **same directory**

## Project Structure

```
.
├── launcher.py            # The Python launcher script
├── minecraft_launcher.py  # Your actual Minecraft launcher logic
└── fabric.command         # Shell script to run Minecraft (no terminal popup)
```

## How to Use

1. Clone or download this repository:

   ```bash
   git clone https://github.com/your-username/fabric-minecraft-launcher.git
   cd fabric-minecraft-launcher
   ```

2. Make sure the `.command` file is executable:

   ```bash
   chmod +x fabric.command
   ```

3. Run the Python launcher:

   ```bash
   python3 launcher.py
   ```

   Or, double-click the `.command` file (once properly configured) for a terminal-less launch.

## How It Works

The `launcher.py` script determines the absolute path of its own directory and launches the `fabric.command` file or `minecraft_launcher.py` from there, ensuring everything works no matter where the script is run from.

## Troubleshooting

* **Permission Denied**: Run `chmod +x fabric.command`.
* **Nothing Happens When Clicked**: Ensure the `.command` file includes a shebang (`#!/bin/bash`) and properly points to `python3`.
