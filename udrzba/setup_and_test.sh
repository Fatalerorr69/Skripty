#!/usr/bin/env bash
set -euo pipefail

VENV_DIR=".venv"
REQ_FILE="requirements.txt"
CAPS_SCRIPT="update_capabilities.py"
DB_FILE="telemetry.db"

echo "=== 1. Kontrola Python 3 ==="
if ! command -v python3 &> /dev/null; then
  echo "Python3 nenalezen. Nainstaluj Python 3.7+."
  exit 1
fi

echo "=== 2. Vytvoření virtuálního prostředí ==="
python3 -m venv $VENV_DIR
source $VENV_DIR/bin/activate

echo "=== 3. Příprava requirements.txt ==="
cat > $REQ_FILE << 'EOF'
Flask
PyYAML
SQLAlchemy
prompt_toolkit
EOF

pip install --upgrade pip
pip install -r $REQ_FILE

echo "=== 4. Vytvoření skriptu pro generování capabilities.yml ==="
cat > $CAPS_SCRIPT << 'EOF'
import os, yaml

def scan_plugins(folder="plugins"):
    if not os.path.isdir(folder):
        return []
    return [d for d in os.listdir(folder)
            if os.path.isdir(os.path.join(folder, d))]

def write_registry(modules, path="capabilities.yml"):
    with open(path, "w") as f:
        yaml.dump({"modules": modules}, f)

if __name__ == "__main__":
    mods = scan_plugins()
    modules = [{
        "name": m,
        "description": "autogen",
        "version": "1.0",
        "inputs": [],
        "outputs": []
    } for m in mods]
    write_registry(modules)
    print(f"Generated {len(modules)} modules in capabilities.yml")
EOF

echo "=== 5. Generování capabilities.yml ==="
python3 $CAPS_SCRIPT

echo "=== 6. Inicializace SQLite DB ==="
cat > init_db.py << 'EOF'
from sqlalchemy import create_engine, Column, Integer, String, DateTime, Boolean, Text, MetaData, Table
from datetime import datetime

engine = create_engine("sqlite:///telemetry.db", echo=False)
meta = MetaData()

usage = Table('usage', meta,
    Column('id',       Integer, primary_key=True),
    Column('module',   String,  nullable=False),
    Column('timestamp',DateTime, default=datetime.utcnow),
    Column('success',  Boolean, nullable=False),
)

feedback = Table('feedback', meta,
    Column('id',       Integer, primary_key=True),
    Column('module',   String,  nullable=False),
    Column('rating',   Integer, nullable=False),
    Column('comment',  Text),
    Column('timestamp',DateTime, default=datetime.utcnow),
)

meta.create_all(engine)
print("Initialized DB with tables:", list(meta.tables.keys()))
EOF

python3 init_db.py
rm init_db.py

echo "=== 7. Příprava testovacího skriptu ==="
cat > test_setup.py << 'EOF'
import yaml, sqlite3

# Test 1: capabilities.yml
print("== Test capabilities.yml ==")
caps = yaml.safe_load(open("capabilities.yml"))["modules"]
print(f"Loaded modules ({len(caps)}):", [m["name"] for m in caps])

# Test 2: telemetry.db
print("== Test telemetry.db ==")
conn = sqlite3.connect("telemetry.db")
cur = conn.cursor()
cur.execute("INSERT INTO usage(module, success) VALUES (?, ?)", ("test_mod", 1))
conn.commit()
cur.execute("SELECT COUNT(*) FROM usage")
count = cur.fetchone()[0]
print(f"Usage table row count: {count}")
conn.close()
EOF

echo "=== 8. Spuštění testů ==="
python3 test_setup.py
rm test_setup.py

echo "=== HOTOVO ==="
echo "Pro aktivaci virtuálního prostředí spusť: source $VENV_DIR/bin/activate"