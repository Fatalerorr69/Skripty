#!/bin/bash
# Automatické aktualizace Docker služeb

LOG_FILE="$HOME/auto-update.log"

echo "$(date) - Starting automatic update" >> "$LOG_FILE"

cd "$HOME/docker-stack"

# Pull latest images
docker-compose pull

# Update containers
docker-compose up -d

# Cleanup
docker system prune -f

echo "$(date) - Update completed" >> "$LOG_FILE"

# Send notification (if notify-send is available)
if command -v notify-send &> /dev/null; then
    notify-send "Docker Services Updated" "All containers have been updated successfully"
fi
