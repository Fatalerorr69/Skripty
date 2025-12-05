#!/bin/bash
set -e
echo "[Setup] Vytvářím systemd službu pro API server"
SERVICE_FILE="/etc/systemd/system/twister-api.service"
sudo tee ${SERVICE_FILE} > /dev/null <<EOF
[Unit]
Description=Twister Smart Suite API
After=network.target

[Service]
Type=simple
User=root
Environment=TWISTER_API_KEY=REPLACE_WITH_STRONG_KEY
ExecStart=/usr/bin/python3 /home/starko/twisteros_supermanager/api/app.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now twister-api.service
