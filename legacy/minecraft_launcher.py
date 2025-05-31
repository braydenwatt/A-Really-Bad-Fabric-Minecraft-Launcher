import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import subprocess
import os
import threading
import json
import requests
from urllib.parse import urlparse, parse_qs
import webbrowser

CONFIG_PATH = os.path.expanduser("~/.minecraft_launcher_config.json")

def clear_fields():
    for label, var in fields:
        var.set('')

def save_config():
    config = {
        "username": username_var.get(),
        "uuid": uuid_var.get(),
        "minecraft_version": minecraft_version_var.get(),
        "fabric_version": fabric_version_var.get(),
        "access_token": access_token_var.get(),
        "java": java_var.get(),
        "install_type": install_type_var.get(),
        "first_launch": False  # once saved, it's no longer first launch
    }
    try:
        with open(CONFIG_PATH, "w") as f:
            json.dump(config, f)
        messagebox.showinfo("Saved", "Configuration saved.")
    except Exception as e:
        messagebox.showerror("Error", f"Failed to save config: {e}")


def load_config():
    if not os.path.exists(CONFIG_PATH):
        return
    try:
        with open(CONFIG_PATH, "r") as f:
            config = json.load(f)
        # Set all fields
        username_var.set(config.get("username", ""))
        uuid_var.set(config.get("uuid", ""))
        mc_ver = config.get("minecraft_version", "")
        fab_ver = config.get("fabric_version", "")

        if mc_ver in minecraft_version_combo['values']:
            minecraft_version_var.set(mc_ver)
        else:
            minecraft_version_combo.configure(values=[mc_ver])
            minecraft_version_var.set(mc_ver)

        if fab_ver in fabric_version_combo['values']:
            fabric_version_var.set(fab_ver)
        else:
            fabric_version_combo.configure(values=[fab_ver])
            fabric_version_var.set(fab_ver)

        access_token_var.set(config.get("access_token", ""))
        java_var.set(config.get("java", ""))
        install_type_var.set(config.get("install_type", "fabric"))
        update_fabric_visibility()

        return config  # return config for checking first_launch
    except Exception as e:
        messagebox.showerror("Error", f"Failed to load config: {e}")


def run_script():
    # Get values
    username = username_var.get()
    uuid = uuid_var.get()
    minecraft_version = minecraft_version_var.get()
    fabric_version = fabric_version_var.get()
    access_token = access_token_var.get()
    java = java_var.get()
    install_type = install_type_var.get()

    # Validate required fields
    if not all([username, uuid, minecraft_version, access_token]):
        messagebox.showerror("Error", "All fields except Fabric Version must be filled out.")
        return
    if install_type == "fabric" and not fabric_version:
        messagebox.showerror("Error", "Fabric version must be specified if Fabric install is selected.")
        return

    script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fabric.command")
    if not os.path.isfile(script_path):
        messagebox.showerror("Error", f"Bash script not found at: {script_path}")
        return

    # Clear previous output
    output_text.configure(state="normal")
    output_text.delete(1.0, tk.END)
    output_text.configure(state="disabled")

    def run_and_capture():
        args = [script_path, username, uuid, minecraft_version]
        if install_type == "fabric":
            args.append(fabric_version)
        else:
            args.append("")  # empty fabric version arg if vanilla
        args.extend([access_token, java])

        process = subprocess.Popen(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True
        )

        for line in process.stdout:
            append_output(line)

        process.stdout.close()
        process.wait()

    def append_output(line):
        output_text.configure(state="normal")
        output_text.insert(tk.END, line)
        output_text.see(tk.END)  # Auto-scroll
        output_text.configure(state="disabled")

    threading.Thread(target=run_and_capture, daemon=True).start()

def install_versions():
    minecraft_version = minecraft_version_var.get()
    fabric_version = fabric_version_var.get()
    install_type = install_type_var.get()

    if not minecraft_version:
        messagebox.showerror("Error", "Minecraft version must be selected for install.")
        return
    if install_type == "fabric" and not fabric_version:
        messagebox.showerror("Error", "Fabric version must be specified for Fabric install.")
        return

    # Select script based on install type
    if install_type == "fabric":
        install_script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "install_fabric.sh")
    else:
        install_script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "download_vanilla.sh")

    if not os.path.isfile(install_script):
        messagebox.showerror("Error", f"Install script not found at: {install_script}")
        return

    # Prepare args based on install type
    if install_type == "fabric":
        args = [install_script, minecraft_version, fabric_version]
    else:
        args = [install_script, minecraft_version]

    def run_install():
        output_text.configure(state="normal")
        output_text.insert(tk.END, f"Running install for Minecraft {minecraft_version} " +
                                   (f"and Fabric {fabric_version}\n" if install_type == "fabric" else " (Vanilla)\n"))
        output_text.configure(state="disabled")

        process = subprocess.Popen(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True
        )
        for line in process.stdout:
            output_text.configure(state="normal")
            output_text.insert(tk.END, line)
            output_text.see(tk.END)
            output_text.configure(state="disabled")

        process.stdout.close()
        process.wait()

    threading.Thread(target=run_install, daemon=True).start()

def update_fabric_visibility():
    if install_type_var.get() == "fabric":
        fabric_label.grid()
        fabric_version_combo.grid()
    else:
        fabric_label.grid_remove()
        fabric_version_combo.grid_remove()

def fetch_versions(callback=None):
    def fetch():
        url = "https://launchermeta.mojang.com/mc/game/version_manifest.json"
        try:
            response = requests.get(url)
            response.raise_for_status()
            data = response.json()
            releases = [v["id"] for v in data["versions"] if v["type"] == "release"]
            def update():
                minecraft_version_combo.configure(values=releases)
                if releases:
                    minecraft_version_var.set(releases[0])
                if callback:
                    callback()
            root.after(0, update)
        except Exception as e:
            print(f"Failed to fetch versions: {e}")
    threading.Thread(target=fetch, daemon=True).start()

def fetch_fabric_versions(callback=None):
    def fetch():
        url = "https://meta.fabricmc.net/v2/versions/loader"
        try:
            response = requests.get(url)
            response.raise_for_status()
            data = response.json()
            versions = [entry["version"] for entry in data]
            def update():
                fabric_version_combo.configure(values=versions)
                if versions:
                    fabric_version_var.set(versions[-1])
                if callback:
                    callback()
            root.after(0, update)
        except Exception as e:
            print(f"Failed to fetch Fabric versions: {e}")
    threading.Thread(target=fetch, daemon=True).start()


# --- Microsoft Authentication Functions ---
def get_code():
    auth_url = (
        'https://login.live.com/oauth20_authorize.srf?client_id=00000000402b5328'
        '&response_type=code&scope=service%3A%3Auser.auth.xboxlive.com%3A%3AMBI_SSL'
        '&redirect_uri=https%3A%2F%2Flogin.live.com%2Foauth20_desktop.srf'
    )
    output_text.configure(state="normal")
    output_text.insert(tk.END, "1/5 Opening the login page in your browser...\n")
    output_text.configure(state="disabled")
    
    webbrowser.open(auth_url)  # Automatically open the URL
    
    # Create a dialog to get the URL
    dialog = tk.Toplevel(root)
    dialog.title("Microsoft Authentication")
    dialog.geometry("600x150")
    dialog.transient(root)
    dialog.grab_set()
    
    ttk.Label(dialog, text="After logging in, you will be redirected to a URL.\nPaste the full redirected URL here:", 
              justify=tk.LEFT).pack(pady=10, padx=10, anchor=tk.W)
    
    url_var = tk.StringVar()
    url_entry = ttk.Entry(dialog, textvariable=url_var, width=70)
    url_entry.pack(pady=5, padx=10, fill=tk.X)
    
    result = [None]  # Using a list to store the result
    
    def on_submit():
        redirect_url = url_var.get().strip()
        parsed = urlparse(redirect_url)
        if parsed.hostname == 'login.live.com' and parsed.path == '/oauth20_desktop.srf':
            query = parse_qs(parsed.query)
            if 'code' in query and 'error' not in query:
                result[0] = query['code'][0]
                dialog.destroy()
            else:
                messagebox.showerror("Error", "Invalid URL: No authorization code found")
        else:
            messagebox.showerror("Error", "Invalid URL: Not a valid Microsoft redirect")
    
    def on_cancel():
        dialog.destroy()
    
    button_frame = ttk.Frame(dialog)
    button_frame.pack(pady=10, fill=tk.X)
    
    ttk.Button(button_frame, text="Submit", command=on_submit).pack(side=tk.RIGHT, padx=10)
    ttk.Button(button_frame, text="Cancel", command=on_cancel).pack(side=tk.RIGHT, padx=10)
    
    dialog.wait_window()
    return result[0]

def get_token(code):
    try:
        response = requests.post('https://login.live.com/oauth20_token.srf', data={
            "client_id": "00000000402b5328",
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": "https://login.live.com/oauth20_desktop.srf",
            "scope": "service::user.auth.xboxlive.com::MBI_SSL"
        })
        json_data = response.json()
        if response.status_code == 200 and 'access_token' in json_data:
            return json_data['access_token']
    except Exception as e:
        append_output(f"Error getting token: {e}\n")
    return None

def auth_xbl(access_token):
    try:
        response = requests.post('https://user.auth.xboxlive.com/user/authenticate', json={
            "Properties": {
                "AuthMethod": "RPS",
                "SiteName": "user.auth.xboxlive.com",
                "RpsTicket": access_token
            },
            "RelyingParty": "http://auth.xboxlive.com",
            "TokenType": "JWT"
        })
        json_data = response.json()
        if response.status_code == 200 and 'Token' in json_data:
            return {
                'Token': json_data['Token'],
                'uhs': json_data['DisplayClaims']['xui'][0]['uhs']
            }
    except Exception as e:
        append_output(f"Error authenticating with XBL: {e}\n")
    return {'Token': None, 'uhs': None}

def auth_xsts(xbl_token, uhs):
    try:
        response = requests.post('https://xsts.auth.xboxlive.com/xsts/authorize', json={
            "Properties": {
                "SandboxId": "RETAIL",
                "UserTokens": [xbl_token]
            },
            "RelyingParty": "rp://api.minecraftservices.com/",
            "TokenType": "JWT"
        })
        json_data = response.json()
        if response.status_code == 200 and 'Token' in json_data:
            new_uhs = json_data['DisplayClaims']['xui'][0]['uhs']
            if uhs == new_uhs:
                return {
                    'Token': json_data['Token'],
                    'uhs': new_uhs
                }
    except Exception as e:
        append_output(f"Error authenticating with XSTS: {e}\n")
    return {'Token': None, 'uhs': None}

def get_minecraft_access_token(token, uhs):
    try:
        response = requests.post('https://api.minecraftservices.com/authentication/login_with_xbox', json={
            "identityToken": f"XBL3.0 x={uhs};{token}"
        })
        json_data = response.json()
        if response.status_code == 200 and 'access_token' in json_data:
            return json_data['access_token']
    except Exception as e:
        append_output(f"Error getting Minecraft access token: {e}\n")
    return None

def get_profile_info(access_token):
    try:
        response = requests.get('https://api.minecraftservices.com/minecraft/profile', headers={
            'Authorization': f'Bearer {access_token}'
        })
        json_data = response.json()
        if response.status_code == 200 and 'id' in json_data and 'name' in json_data:
            return {'UUID': json_data['id'], 'name': json_data['name']}
    except Exception as e:
        append_output(f"Error getting profile info: {e}\n")
    return {'UUID': None, 'name': None}

def check_game_ownership(access_token):
    try:
        response = requests.get('https://api.minecraftservices.com/entitlements/mcstore', headers={
            'Authorization': f'Bearer {access_token}'
        })
        json_data = response.json()
        if response.status_code == 200 and 'items' in json_data:
            return len(json_data['items']) > 0
    except Exception as e:
        append_output(f"Error checking game ownership: {e}\n")
    return False

def append_output(text):
    output_text.configure(state="normal")
    output_text.insert(tk.END, text)
    output_text.see(tk.END)
    output_text.configure(state="disabled")

def authenticate_microsoft():
    def run_auth():
        append_output("Starting Microsoft authentication process...\n")
        
        code = get_code()
        if not code:
            append_output("❌ Failed to obtain authorization code.\n")
            return
            
        append_output("2/5 Exchanging code for Microsoft access token…\n")
        token = get_token(code)
        if not token:
            append_output("❌ Failed to get Microsoft Access Token!\n")
            return
            
        append_output("3/5 Authenticating with Xbox Live…\n")
        xbl = auth_xbl(token)
        if not xbl['Token']:
            append_output("❌ Failed to authenticate with Xbox Live!\n")
            return
            
        append_output("4/5 Authenticating with XSTS…\n")
        xsts = auth_xsts(xbl['Token'], xbl['uhs'])
        if not xsts['Token']:
            append_output("❌ Failed to authenticate with XSTS!\n")
            return
            
        append_output("5/5 Getting Minecraft access token…\n")
        mc_access_token = get_minecraft_access_token(xsts['Token'], xsts['uhs'])
        if not mc_access_token:
            append_output("❌ Failed to get Minecraft Access Token!\n")
            return
            
        append_output(f"✅ Minecraft Access Token obtained successfully!\n")
        
        # Check game ownership and get profile
        has_game = check_game_ownership(mc_access_token)
        if not has_game:
            append_output("❌ You do not own Minecraft: Java Edition.\n")
            return
            
        profile = get_profile_info(mc_access_token)
        if not profile['UUID'] or not profile['name']:
            append_output("❌ Failed to get profile information.\n")
            return
            
        # Update GUI fields
        def update_fields():
            username_var.set(profile['name'])
            uuid_var.set(profile['UUID'])
            access_token_var.set(mc_access_token)
            append_output(f"\n✅ Authentication complete!\nUsername: {profile['name']}\nUUID: {profile['UUID']}\n")
            
            # Save to configuration
            save_config()
            
        root.after(0, update_fields)
        
    threading.Thread(target=run_auth, daemon=True).start()


# --- GUI Setup ---
root = tk.Tk()
root.title("Minecraft Launcher UI")

input_frame = ttk.Frame(root, padding="10")
input_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

username_var = tk.StringVar()
uuid_var = tk.StringVar()
minecraft_version_var = tk.StringVar()
fabric_version_var = tk.StringVar()
access_token_var = tk.StringVar()
java_var = tk.StringVar()
install_type_var = tk.StringVar(value="fabric")  # default to fabric

fields = [
    ("Username:", username_var),
    ("UUID:", uuid_var),
    # Minecraft version will be a dropdown, so no ttk.Entry here
    # Fabric version only visible if fabric selected
    ("Access Token:", access_token_var),
]

# Username, UUID, Profile Name inputs
for i, (label, var) in enumerate(fields):
    ttk.Label(input_frame, text=label).grid(row=i, column=0, sticky=tk.W, pady=2)
    ttk.Entry(input_frame, textvariable=var, width=50).grid(row=i, column=1, pady=2)

ttk.Button(input_frame, text="MS Login", command=authenticate_microsoft, width=15).grid(row=3, column=1, padx=5)

ttk.Label(input_frame, text="Java Path:").grid(row=4, column=0, sticky=tk.W, pady=2)
ttk.Entry(input_frame, textvariable=java_var, width=50).grid(row=4, column=1, pady=2)

# Install Type Radiobuttons (Vanilla / Fabric)
ttk.Label(input_frame, text="Install Type:").grid(row=len(fields)+2, column=0, sticky=tk.W, pady=5)
install_frame = ttk.Frame(input_frame)
install_frame.grid(row=len(fields)+2, column=1, sticky=tk.W, pady=5, padx=320)

ttk.Radiobutton(install_frame, text="Fabric", variable=install_type_var, value="fabric", command=update_fabric_visibility).grid(row=0, column=0)
ttk.Radiobutton(install_frame, text="Vanilla", variable=install_type_var, value="vanilla", command=update_fabric_visibility).grid(row=0, column=1, padx=30)

# Minecraft Version Dropdown
ttk.Label(input_frame, text="Minecraft Version:").grid(row=len(fields)+3, column=0, sticky=tk.W, pady=2)
minecraft_version_combo = ttk.Combobox(input_frame, textvariable=minecraft_version_var, width=47)
minecraft_version_combo.grid(row=len(fields)+3, column=1, pady=2)

# Fabric Version input (hidden by default if install_type == vanilla)
fabric_label = ttk.Label(input_frame, text="Fabric Version:")
fabric_version_combo = ttk.Combobox(input_frame, textvariable=fabric_version_var, width=47, state="normal")
fabric_label.grid(row=len(fields)+4, column=0, sticky=tk.W, pady=2)
fabric_version_combo.grid(row=len(fields)+4, column=1, pady=2)

# Buttons frame
button_frame = ttk.Frame(input_frame)
button_frame.grid(row=len(fields)+5, column=0, columnspan=2, pady=10)

def open_folder():
    path = os.path.expanduser("~/Library/Application Support/ReallyBadLauncher")
    subprocess.run(["open", path])

ttk.Button(button_frame, text="Launch Game", command=run_script, width=15).grid(row=0, column=0, padx=5)
ttk.Button(button_frame, text="Install Versions", command=install_versions, width=15).grid(row=0, column=1, padx=5)
ttk.Button(button_frame, text="Save Config", command=save_config, width=15).grid(row=0, column=2, padx=5)
ttk.Button(button_frame, text="Load Config", command=load_config, width=15).grid(row=0, column=3, padx=5)
ttk.Button(button_frame, text="Open Minecraft Folder", command=open_folder, width=15).grid(row=0, column=4, padx=5)

# --- Output Box ---
output_text = scrolledtext.ScrolledText(root, width=100, height=20, state="disabled", font=("Courier", 10))
output_text.grid(row=1, column=0, padx=10, pady=(0, 10))


def ensure_minecraft_directory():
    app_support_dir = os.path.expanduser("~/Library/Application Support")
    minecraft_dir = os.path.join(app_support_dir, "ReallyBadLauncher")
    if not os.path.isdir(minecraft_dir):
        create_script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "create_minecraft_directory.sh")
        if os.path.isfile(create_script):
            output_text.configure(state="normal")
            output_text.insert(tk.END, f"Creating Minecraft directory at {minecraft_dir}\n")
            output_text.configure(state="disabled")

            def run_create():
                process = subprocess.Popen(
                    [create_script],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True
                )
                for line in process.stdout:
                    output_text.configure(state="normal")
                    output_text.insert(tk.END, line)
                    output_text.see(tk.END)
                    output_text.configure(state="disabled")

                process.stdout.close()
                process.wait()

            threading.Thread(target=run_create, daemon=True).start()
        else:
            messagebox.showerror("Error", f"Missing: {create_script}")

def init():
    def after_fabric():
        config = load_config()
        if config is None or config.get("first_launch", True):
            create_script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "create_minecraft_directory.sh")
            if os.path.isfile(create_script):
                def run_create_dir():
                    output_text.configure(state="normal")
                    output_text.insert(tk.END, "Running first-time setup script...\n")
                    output_text.configure(state="disabled")

                    process = subprocess.Popen(
                        [create_script],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT,
                        text=True
                    )
                    for line in process.stdout:
                        output_text.configure(state="normal")
                        output_text.insert(tk.END, line)
                        output_text.see(tk.END)
                        output_text.configure(state="disabled")

                    process.stdout.close()
                    process.wait()

                    # Now mark first_launch as False
                    save_config()

                threading.Thread(target=run_create_dir, daemon=True).start()
            else:
                messagebox.showerror("Error", f"Missing: {create_script}")
    fetch_versions(callback=lambda: fetch_fabric_versions(callback=after_fabric))

update_fabric_visibility()
ensure_minecraft_directory()
init()

root.mainloop()