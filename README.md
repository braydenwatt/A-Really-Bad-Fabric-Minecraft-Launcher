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

1. Download the latest [release](https://github.com/braydenwatt/A-Really-Bad-Fabric-Minecraft-Launcher/releases/tag/v0.1.0)

2. Make sure the `.command` file is executable:

   ```bash
   chmod +x fabric.command
   ```

3. Run the Python launcher:

   ```bash
   python3 launcher.py
   ```

   Or, double-click the `.command` file (once properly configured) for a terminal-less launch.
   
4. Use the launcher:
   1. Enter your **Username**.
   2. Enter your **UUID** from [namemc](namemc.com).
   3. Enter the profile name for the modrinth instance you want to use. Find it by navigating to `/Users/YOURNAME/Library/Application Support/com.modrinth.theseus/profiles` and looking for the one you want. Copy the name of the **folder**.
   4. Enter the version of fabric you want to play. You can find it by navigating to `/Users/YOURNAME/Library/Application Support/com.modrinth.theseus/meta/versions`. You likely want the latest version of minecraft and fabric (1.21.5-x.xx.x).
   5. Enter your **access token** [instructions](https://kqzz.github.io/mc-bearer-token/).
   6. **TROUBLESHOOT** if you get an error about invalid java or java not found:
      1. Download Java from Self Service
      2. Enter `/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home` in the **Java Path**

## How It Works

The `launcher.py` script determines the absolute path of its own directory and launches the `fabric.command` file or `minecraft_launcher.py` from there, ensuring everything works no matter where the script is run from.

## Troubleshooting

* **Permission Denied**: Run `chmod +x fabric.command`.
* **Nothing Happens When Clicked**: Ensure the `.command` file includes a shebang (`#!/bin/bash`) and properly points to `python3`.
