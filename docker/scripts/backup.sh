#!/bin/bash

# backup.sh: Script to backup Docker volume data from all stacks.
# Usage: ./backup.sh <backup_destination>
# Example: ./backup.sh /mnt/backup/docker-backup

set -e  # Exit on errors

# Check for backup destination argument
if [ -z "$1" ]; then
    echo "Usage: $0 <backup_destination>"
    echo "Example: $0 /mnt/backup/docker-backup"
    exit 1
fi

BACKUP_DEST="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$BACKUP_DEST/backup_$TIMESTAMP"

echo "=== Docker Volumes Backup Script ==="
echo "Docker directory: $DOCKER_DIR"
echo "Backup destination: $BACKUP_DIR"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Function to backup a stack's config/data directories
backup_stack() {
    local stack_name=$1
    local stack_path="$DOCKER_DIR/$stack_name"

    if [ ! -d "$stack_path" ]; then
        echo "Stack $stack_name not found, skipping."
        return
    fi

    echo "Backing up $stack_name..."
    local stack_backup="$BACKUP_DIR/$stack_name"
    mkdir -p "$stack_backup"

    # Backup config directory if exists
    if [ -d "$stack_path/config" ]; then
        echo "  - Backing up config/"
        cp -r "$stack_path/config" "$stack_backup/"
    fi

    # Backup data directory if exists
    if [ -d "$stack_path/data" ]; then
        echo "  - Backing up data/"
        cp -r "$stack_path/data" "$stack_backup/"
    fi

    # Backup assets directory if exists (for management/glance)
    if [ -d "$stack_path/assets" ]; then
        echo "  - Backing up assets/"
        cp -r "$stack_path/assets" "$stack_backup/"
    fi

    # Backup logs directory if exists
    if [ -d "$stack_path/logs" ]; then
        echo "  - Backing up logs/"
        cp -r "$stack_path/logs" "$stack_backup/"
    fi

    # Backup .env file if exists (contains sensitive data, handle with care)
    if [ -f "$stack_path/.env" ]; then
        echo "  - Backing up .env"
        cp "$stack_path/.env" "$stack_backup/"
    fi

    echo "$stack_name backup complete."
    echo ""
}

# Backup all stacks
echo "=== Starting Backup ==="
echo ""

backup_stack "proxy"
backup_stack "management"
backup_stack "apps"
backup_stack "monitoring"
backup_stack "games"

echo "=== Backup Complete ==="
echo "Backup saved to: $BACKUP_DIR"
echo ""

# Optional: Create compressed archive
read -p "Create compressed archive? (y/n): " create_archive
if [[ "$create_archive" == "y" ]]; then
    ARCHIVE_NAME="$BACKUP_DEST/backup_$TIMESTAMP.tar.gz"
    echo "Creating archive: $ARCHIVE_NAME"
    tar -czf "$ARCHIVE_NAME" -C "$BACKUP_DEST" "backup_$TIMESTAMP"
    echo "Archive created successfully."

    read -p "Remove uncompressed backup directory? (y/n): " remove_dir
    if [[ "$remove_dir" == "y" ]]; then
        rm -rf "$BACKUP_DIR"
        echo "Uncompressed backup removed."
    fi
fi

echo ""
echo "Backup process finished!"
