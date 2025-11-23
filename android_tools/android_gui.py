#!/usr/bin/env python3
import tkinter as tk
from tkinter import messagebox
import subprocess
import os

TOOLS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "android_tools")

def run_script(script_name):
    script_path = os.path.join(TOOLS_DIR, script_name)
    if not os.path.exists(script_path):
        messagebox.showerror("Chyba", f"Skript {script_name} nebyl nalezen.")
        return
    subprocess.Popen(["x-terminal-emulator", "-e", "bash", script_path])

def adb_command(command):
    try:
        output = subprocess.check_output(["adb"] + command.split(), stderr=subprocess.STDOUT)
        messagebox.showinfo("Výstup", output.decode())
    except subprocess.CalledProcessError as e:
        messagebox.showerror("Chyba ADB", e.output.decode())

root = tk.Tk()
root.title("UltraOS Android Toolkit")
root.geometry("400x500")
root.resizable(False, False)

tk.Label(root, text="🔧 UltraOS Android Toolkit", font=("Helvetica", 16, "bold")).pack(pady=10)

buttons = [
    ("FRP Bypass Toolkit", "adb_bypass.sh"),
    ("Flash Magisk Boot Image", "flash_magisk.sh"),
    ("Samsung FRP Settings Launch", "frp_bypass.sh"),
    ("Restart do módu", "reboot_modes.sh"),
    ("Informace o zařízení", "device_info.sh"),
    ("Kontrola rootu", "root_check.sh"),
    ("Push a spustit payload", "push_payload.sh"),
]

for label, script in buttons:
    tk.Button(root, text=label, width=40, command=lambda s=script: run_script(s)).pack(pady=5)

tk.Label(root, text="--- Ostatní funkce ---").pack(pady=10)
tk.Button(root, text="Otevřít ADB Shell", width=40, command=lambda: adb_command("shell")).pack(pady=2)
tk.Button(root, text="Restart ADB serveru", width=40, command=lambda: adb_command("kill-server && adb start-server")).pack(pady=2)
tk.Button(root, text="Odpojit ADB zařízení", width=40, command=lambda: adb_command("disconnect")).pack(pady=2)

tk.Button(root, text="Zavřít", width=20, command=root.destroy).pack(pady=20)

root.mainloop()