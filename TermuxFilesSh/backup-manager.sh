#!/bin/bash
# Pokročilý správce záloh pro Docker stack

BACKUP_DIR="$HOME/docker-backups"
CONFIG_DIR="$HOME/docker-stack/config"

create_backup() {
    local backup_name="backup-$(date +%Y%m%d-%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    echo "Creating backup: $backup_path"
    mkdir -p "$backup_path"
    
    # Backup configuration
    cp -r "$CONFIG_DIR" "$backup_path/"
    
    # Backup docker-compose
    cp "$HOME/docker-stack/docker-compose.yml" "$backup_path/"
    
    # Backup database volumes
    docker ps --format "{{.Names}}" | grep -E "(mysql|postgres|mariadb)" | while read container; do
        docker exec "$container" sh -c 'command -v mysqldump' && \
        docker exec "$container" mysqldump -u root --all-databases > "$backup_path/${container}-db.sql"
    done
    
    # Compress backup
    tar -czf "$backup_path.tar.gz" -C "$BACKUP_DIR" "$backup_name"
    rm -rf "$backup_path"
    
    echo "Backup created: $backup_path.tar.gz"
}

list_backups() {
    echo "Available backups:"
    ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null | while read file; do
        echo "  $(basename "$file") - $(date -r "$file" "+%Y-%m-%d %H:%M:%S")"
    done
}

# Main execution
case "$1" in
    create)
        create_backup
        ;;
    list)
        list_backups
        ;;
    *)
        echo "Usage: $0 {create|list}"
        exit 1
        ;;
esac
