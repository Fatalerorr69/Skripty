import os
import subprocess
import sys
import shutil

# Barvy pro výstup
class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    ENDC = '\033[0m'

def run_command(command, success_message, error_message, requires_root=False):
    """Spustí externí příkaz a vypíše výsledek."""
    if requires_root and os.getuid() != 0:
        print(f"{Colors.RED}Chyba: Tato operace musí být spuštěna jako root (s 'sudo').{Colors.ENDC}")
        return False
        
    print(f"{Colors.YELLOW}Spouštím příkaz: {' '.join(command)}{Colors.ENDC}")
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in process.stdout:
            print(f"  {line.strip()}")
        process.wait()
        if process.returncode == 0:
            print(f"{Colors.GREEN}{success_message}{Colors.ENDC}")
            return True
        else:
            print(f"{Colors.RED}{error_message}{Colors.ENDC}")
            return False
    except FileNotFoundError:
        print(f"{Colors.RED}Chyba: Příkaz '{command[0]}' nebyl nalezen. Ujistěte se, že je QEMU nainstalováno a v PATH.{Colors.ENDC}")
        return False
    except subprocess.CalledProcessError:
        print(f"{Colors.RED}{error_message}{Colors.ENDC}")
        return False

def check_file_exists(file_path):
    """Zkontroluje, zda soubor existuje a zda je to platný obraz disku."""
    if not os.path.exists(file_path):
        print(f"{Colors.RED}Chyba: Soubor '{file_path}' neexistuje.{Colors.ENDC}")
        return False
    if not os.path.isfile(file_path):
        print(f"{Colors.RED}Chyba: '{file_path}' není soubor.{Colors.ENDC}")
        return False
    return True

def get_disk_list():
    """Získá seznam fyzických disků pro bezpečnější výběr."""
    print("Skenuji dostupná fyzická zařízení...")
    try:
        result = subprocess.run(['lsblk', '-o', 'NAME,SIZE,MODEL', '-p'], stdout=subprocess.PIPE, text=True, check=True)
        disks = [line.split() for line in result.stdout.splitlines()[1:]]
        disk_map = {str(i): d[0] for i, d in enumerate(disks)}
        
        print(f"\n{Colors.YELLOW}Dostupné fyzické disky:{Colors.ENDC}")
        for i, disk_info in enumerate(disks):
            print(f"{i}: {disk_info[0]} ({disk_info[1]} - {disk_info[2]})")
        return disk_map
    except Exception as e:
        print(f"{Colors.RED}Chyba při získávání seznamu disků: {e}{Colors.ENDC}")
        return {}

def create_disk_image():
    print("\n--- Vytvoření nového disku ---")
    file_name = input("Zadejte název souboru (např. kali_linux.qcow2): ")
    if os.path.exists(file_name):
        print(f"{Colors.RED}Soubor '{file_name}' již existuje. Vyberte jiný název.{Colors.ENDC}")
        return

    format_choice = input("Zadejte formát disku (qcow2 nebo raw): ").lower()
    if format_choice not in ['qcow2', 'raw']:
        print(f"{Colors.RED}Neplatný formát. Zvolte 'qcow2' nebo 'raw'.{Colors.ENDC}")
        return

    size_str = input("Zadejte velikost disku (např. 20G pro 20 GB): ")
    if not size_str.endswith(('G', 'M', 'T')):
        print(f"{Colors.RED}Neplatný formát velikosti. Použijte G, M nebo T.{Colors.ENDC}")
        return

    command = ['qemu-img', 'create', '-f', format_choice, file_name, size_str]
    run_command(command, f"Úspěšně vytvořen obraz disku '{file_name}'.", "Vytvoření disku selhalo.")

def convert_disk_image():
    print("\n--- Převod obrazu disku ---")
    source_file = input("Zadejte název zdrojového souboru: ")
    if not check_file_exists(source_file): return

    target_file = input("Zadejte název cílového souboru: ")
    if os.path.exists(target_file):
        print(f"{Colors.RED}Cílový soubor '{target_file}' již existuje. Vyberte jiný název.{Colors.ENDC}")
        return

    target_format = input("Zadejte cílový formát (qcow2 nebo raw): ").lower()
    if target_format not in ['qcow2', 'raw']:
        print(f"{Colors.RED}Neplatný formát. Zvolte 'qcow2' nebo 'raw'.{Colors.ENDC}")
        return

    command = ['qemu-img', 'convert', '-f', 'auto', '-O', target_format, source_file, target_file]
    run_command(command, f"Úspěšně převeden obraz disku na '{target_file}'.", "Převod disku selhal.")

def show_disk_info():
    print("\n--- Zobrazení informací o disku ---")
    file_name = input("Zadejte název souboru: ")
    if not check_file_exists(file_name): return

    command = ['qemu-img', 'info', file_name]
    run_command(command, "Informace byly úspěšně zobrazeny.", "Zobrazení informací selhalo.")

def convert_to_physical_disk():
    print("\n--- KLONOVÁNÍ NA FYZICKÝ DISK ---")
    print(f"{Colors.RED}!!! Upozornění: Tato operace PŘEPIŠE VŠECHNA DATA na cílovém disku. !!!{Colors.ENDC}")
    
    source_file = input("Zadejte název zdrojového souboru (virtuální obraz): ")
    if not check_file_exists(source_file): return

    disk_map = get_disk_list()
    if not disk_map: return

    choice = input("Zadejte číslo cílového disku: ")
    if choice not in disk_map:
        print(f"{Colors.RED}Neplatná volba.{Colors.ENDC}")
        return
    
    target_disk = disk_map[choice]
    
    confirm = input(f"Jste si JISTI, že chcete přepsat disk '{target_disk}'? (ano/ne): ")
    if confirm.lower() != 'ano':
        print(f"{Colors.YELLOW}Operace zrušena.{Colors.ENDC}")
        return

    command = ['qemu-img', 'convert', '-f', 'qcow2', '-O', 'raw', source_file, target_disk]
    run_command(command, "Klonování disku bylo úspěšné.", "Klonování selhalo.", requires_root=True)

def manage_snapshots():
    print("\n--- SPRÁVA SNÍMKŮ ---")
    file_name = input("Zadejte název souboru: ")
    if not check_file_exists(file_name): return

    print("\nMožnosti:")
    print("1. Vytvořit snímek")
    print("2. Zobrazit snímky")
    print("3. Vrátit se ke snímku")
    print("4. Smazat snímek")
    
    choice = input("Zadejte číslo volby: ")
    
    if choice == '1':
        snapshot_name = input("Zadejte název snímku: ")
        command = ['qemu-img', 'snapshot', '-c', snapshot_name, file_name]
        run_command(command, "Snímek byl úspěšně vytvořen.", "Vytvoření snímku selhalo.")
    elif choice == '2':
        command = ['qemu-img', 'snapshot', '-l', file_name]
        run_command(command, "Seznam snímků byl zobrazen.", "Zobrazení snímků selhalo.")
    elif choice == '3':
        snapshot_name = input("Zadejte název snímku, ke kterému se chcete vrátit: ")
        command = ['qemu-img', 'snapshot', '-a', snapshot_name, file_name]
        run_command(command, "Úspěšně vráceno ke snímku.", "Vrácení ke snímku selhalo.")
    elif choice == '4':
        snapshot_name = input("Zadejte název snímku ke smazání: ")
        command = ['qemu-img', 'snapshot', '-d', snapshot_name, file_name]
        run_command(command, "Snímek byl úspěšně smazán.", "Smazání snímku selhalo.")
    else:
        print(f"{Colors.RED}Neplatná volba.{Colors.ENDC}")

def resize_disk():
    print("\n--- ZMĚNA VELIKOSTI DISKU ---")
    file_name = input("Zadejte název souboru: ")
    if not check_file_exists(file_name): return

    new_size = input("Zadejte novou velikost disku (např. 30G): ")
    if not new_size.endswith(('G', 'M', 'T')):
        print(f"{Colors.RED}Neplatný formát velikosti. Použijte G, M nebo T.{Colors.ENDC}")
        return

    print("Upozornění: Zvětšení disku je bezpečné. Zmenšení vyžaduje nejprve zmenšení oddílů uvnitř obrazu.")
    command = ['qemu-img', 'resize', file_name, new_size]
    run_command(command, "Velikost disku byla úspěšně změněna.", "Změna velikosti selhala.")

def main():
    if not shutil.which('qemu-img'):
        print(f"{Colors.RED}Chyba: 'qemu-img' nebyl nalezen. Ujistěte se, že je QEMU nainstalováno a v PATH.{Colors.ENDC}")
        sys.exit(1)
        
    while True:
        print(f"\n{Colors.GREEN}--- UNIVERZÁLNÍ NÁSTROJ PRO SPRÁVU DISKŮ ---{Colors.ENDC}")
        print(f"{Colors.YELLOW}Vyberte operaci:{Colors.ENDC}")
        print("1. Vytvořit nový obraz disku")
        print("2. Převést obraz disku (mezi formáty)")
        print("3. Zobrazit informace o disku")
        print("4. Klonovat virtuální obraz na fyzický disk")
        print("5. Správa snímků (snapshots)")
        print("6. Změnit velikost disku")
        print("7. Ukončit")
        
        choice = input("Zadejte číslo volby: ")
        
        if choice == '1':
            create_disk_image()
        elif choice == '2':
            convert_disk_image()
        elif choice == '3':
            show_disk_info()
        elif choice == '4':
            convert_to_physical_disk()
        elif choice == '5':
            manage_snapshots()
        elif choice == '6':
            resize_disk()
        elif choice == '7':
            print("Skript byl ukončen.")
            sys.exit()
        else:
            print(f"{Colors.RED}Neplatná volba. Zadejte platné číslo.{Colors.ENDC}")

if __name__ == "__main__":
    main()