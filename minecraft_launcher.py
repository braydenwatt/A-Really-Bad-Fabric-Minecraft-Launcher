import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import subprocess
import os
import threading
import json

CONFIG_PATH = os.path.expanduser("~/.minecraft_launcher_config.json")

def clear_fields():
    for label, var in fields:
        var.set('')

def save_config():
    config = {
        "username": username_var.get(),
        "uuid": uuid_var.get(),
        "profile_name": profile_name_var.get(),
        "minecraft_version": minecraft_version_var.get(),
        "fabric_version": fabric_version_var.get(),
        "access_token": access_token_var.get(),
        "java": java_var.get(),
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
        username_var.set(config.get("username", ""))
        uuid_var.set(config.get("uuid", ""))
        profile_name_var.set(config.get("profile_name", ""))
        minecraft_version_var.set(config.get("minecraft_version", ""))
        fabric_version_var.set(config.get("fabric_version", ""))
        access_token_var.set(config.get("access_token", ""))
        java_var.set(config.get("java", ""))
    except Exception as e:
        messagebox.showerror("Error", f"Failed to load config: {e}")

def run_script():
    username = username_var.get()
    uuid = uuid_var.get()
    profile_name = profile_name_var.get()
    minecraft_version = minecraft_version_var.get()
    fabric_version = fabric_version_var.get()
    access_token = access_token_var.get()
    java = java_var.get()

    if not all([username, uuid, profile_name, minecraft_version, fabric_version, access_token]):
        messagebox.showerror("Error", "All fields must be filled out.")
        return

    script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fabric.command")
    print(script_path)
    if not os.path.isfile(script_path):
        messagebox.showerror("Error", f"Bash script not found at: {script_path}")
        return

    # Clear previous output
    output_text.configure(state="normal")
    output_text.delete(1.0, tk.END)
    output_text.configure(state="disabled")

    def run_and_capture():
        process = subprocess.Popen(
            [script_path, username, uuid, profile_name, minecraft_version, fabric_version, access_token, java],
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

# --- GUI Setup ---
root = tk.Tk()
root.title("Minecraft Launcher UI")

input_frame = ttk.Frame(root, padding="10")
input_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

username_var = tk.StringVar()
uuid_var = tk.StringVar()
profile_name_var = tk.StringVar()
minecraft_version_var = tk.StringVar()
fabric_version_var = tk.StringVar()
access_token_var = tk.StringVar()
java_var = tk.StringVar()

fields = [
    ("Username:", username_var),
    ("UUID:", uuid_var),
    ("Profile Name:", profile_name_var),
    ("Minecraft Version:", minecraft_version_var),
    ("Fabric Version:", fabric_version_var),
    ("Access Token:", access_token_var),
    ("Java Path:", java_var)
]



for i, (label, var) in enumerate(fields):
    ttk.Label(input_frame, text=label).grid(row=i, column=0, sticky=tk.W, pady=2)
    ttk.Entry(input_frame, textvariable=var, width=50).grid(row=i, column=1, pady=2)

load_config()
# Create a frame just for the buttons
button_frame = ttk.Frame(input_frame)
button_frame.grid(row=len(fields)+1, column=0, columnspan=4, pady=5)

# Place buttons with minimal or negative padding
ttk.Button(button_frame, text="Launch Game", command=run_script, width=10).grid(row=0, column=0, padx=10)
ttk.Button(button_frame, text="Save Config", command=save_config, width=10).grid(row=0, column=1, padx=10)
ttk.Button(button_frame, text="Load Config", command=load_config, width=10).grid(row=0, column=2, padx=10)
ttk.Button(button_frame, text="Clear", command=clear_fields, width=10).grid(row=0, column=3, padx=10)

# --- Output Box ---
output_text = scrolledtext.ScrolledText(root, width=100, height=20, state="disabled", font=("Courier", 10))
output_text.grid(row=1, column=0, padx=10, pady=(0, 10))

root.mainloop()