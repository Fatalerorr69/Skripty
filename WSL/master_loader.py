#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import subprocess
import platform
import shutil

# -----------------------------
# Konfigurace
# -----------------------------
HOME_DRIVE = "W:"  # Windows disk, pokud běží WSL
TERMUX_HOME = "/data/data/com.termux/files/home"
RECOMMENDED_MODULES = [
    "docker.io", "docker-compose", "waydroid", "rclone", "borgbackup",
    "tmuxinator", "tmate", "jq", "yq", "mosquitto", "vnc4server",
    "oh-my-zsh", "neofetch"
]

# -----------------------------
# Prostředí
# -----------------------------
SYSTEM = platform.system()
IS_WSL = "microsoft" in platform.release().lower()
IS_TERMUX = os.path.exists(TERMUX_HOME)

def run(cmd):
    try:
        result = subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] {e}")
        return None

def detect_distro():
    distros = []
    if IS_WSL:
        output = run("wsl --list --verbose")
        if output:
            for line in output.splitlines()[1:]:
                if line.strip() and not line.startswith("NAME"):
                    distros.append(line.strip().split()[0])
    elif SYSTEM == "Linux" and not IS_TERMUX:
        distros.append(run("lsb_release -si") or "linux-distro")
    elif IS_TERMUX:
        distros.append("termux")
    return distros

# -----------------------------
# Funkce pro nastavení domácích adresářů
# -----------------------------
def set_home_dirs(distros):
    for d in distros:
        if IS_WSL:
            home_path = f"{HOME_DRIVE}\\{d}\\home"
            os.makedirs(home_path, exist_ok=True)
            run(f"wsl -d {d} -- ln -sfn /mnt/{HOME_DRIVE.lower()}/{d}/home /home/starko")
            run(f"wsl --distribution {d} --user root -- bash -c 'usermod -d /mnt/{HOME_DRIVE.lower()}/{d}/home starko || true'")
            print(f"[INFO] Nastaven domovský adresář pro {d} -> {home_path}")
        elif IS_TERMUX:
            print(f"[INFO] Termux domovský adresář je {TERMUX_HOME}")
        else:
            home_path = os.path.expanduser("~")
            print(f"[INFO] Linux domovský adresář: {home_path}")

# -----------------------------
# Instalace modulů
# -----------------------------
def install_modules(distro, modules):
    print(f"[INFO] Instalace modulů pro {distro}...")
    if IS_WSL or SYSTEM == "Linux":
        run("sudo apt update && sudo apt upgrade -y")
        for m in modules:
            run(f"sudo apt install -y {m}")
    elif IS_TERMUX:
        run("pkg update && pkg upgrade -y")
        for m in modules:
            run(f"pkg install -y {m}")

# -----------------------------
# Cleaner PRO Advanced
# -----------------------------
def cleaner_pro(distro):
    print(f"[INFO] Spouštím Cleaner PRO Advanced pro {distro}...")
    if IS_WSL or SYSTEM == "Linux":
        run("sudo docker system prune -af || true")
        run("sudo rm -rf ~/.local/share/waydroid/* || true")
        run("pip cache purge || true")
    elif IS_TERMUX:
        run("rm -rf ~/.cache/*")
        run("pip cache purge || true")

# -----------------------------
# Instalace WebGUI
# -----------------------------
def install_webgui(distro):
    print(f"[INFO] Instalace WebGUI modulu pro {distro}...")
    if IS_WSL or SYSTEM == "Linux":
        run("sudo apt install -y python3-flask python3-pip git")
        run("pip3 install flask flask_cors flask_socketio")
    elif IS_TERMUX:
        run("pkg install -y python git")
        run("pip install flask flask_cors flask_socketio")

# -----------------------------
# Interaktivní menu
# -----------------------------
def main_menu():
    while True:
        print("\n==== WSL/Termux/Unix PRO MAX MENU ====")
        print("1) Detekce distribucí")
        print("2) Nastavení domovských adresářů")
        print("3) Instalace základních modulů")
        print("4) Instalace rozšířených modulů")
        print("5) Cleaner PRO Advanced")
        print("6) Instalace WebGUI")
        print("0) Bezpečné ukončení")
        choice = input("Vyberte možnost: ").strip()

        distros = detect_distro()

        if choice == "1":
            print("[OK] Nalezené distribuce:", ", ".join(distros))
        elif choice == "2":
            set_home_dirs(distros)
        elif choice == "3":
            for d in distros:
                install_modules(d, RECOMMENDED_MODULES[:5])
        elif choice == "4":
            for d in distros:
                install_modules(d, RECOMMENDED_MODULES)
        elif choice == "5":
            for d in distros:
                cleaner_pro(d)
        elif choice == "6":
            for d in distros:
                install_webgui(d)
        elif choice == "0":
            print("[INFO] Ukončení...")
            sys.exit(0)
        else:
            print("[WARN] Neplatná volba!")

# -----------------------------
# Spuštění
# -----------------------------
if __name__ == "__main__":
    main_menu()
