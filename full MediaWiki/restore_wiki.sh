#!/bin/bash

# MediaWiki Restore Script for Kryptionary
# This script restores a backup created by backup_wiki.sh

# Configuration
WIKI_DIR="/Applications/MAMP/htdocs/kryptionary"
BACKUP_DIR="$WIKI_DIR/backups"

# Database configuration
DB_NAME="kryptionary_db"
DB_USER="root"
DB_PASS="root"
DB_HOST="localhost"
DB_PORT="8889"

# MAMP MySQL path
MYSQL_BIN="/Applications/MAMP/Library/bin/mysql80/bin/mysql"

# Check if backup file was provided
if [ -z "$1" ]; then
    echo "================================================"
    echo "Kryptionary Wiki Restore Script"
    echo "================================================"
    echo ""
    echo "Usage: $0 <backup_file.tar.gz>"
    echo ""
    echo "Available backups:"
    ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "  No backups found"
    echo ""
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "✗ Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "================================================"
echo "Starting Kryptionary Wiki Restore"
echo "================================================"
echo "Backup file: $BACKUP_FILE"
echo ""

# Warning
echo "⚠️  WARNING: This will overwrite your current wiki data!"
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

# Extract backup
echo ""
echo "[1/4] Extracting backup archive..."
TEMP_DIR="/tmp/wiki_restore_$$"
mkdir -p "$TEMP_DIR"
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

if [ $? -eq 0 ]; then
    echo "✓ Archive extracted successfully"
else
    echo "✗ Failed to extract archive"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Find the extracted directory
EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)

if [ -z "$EXTRACTED_DIR" ]; then
    echo "✗ Could not find extracted backup directory"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Restore database
echo ""
echo "[2/4] Restoring database..."
if [ -f "$EXTRACTED_DIR/database.sql" ]; then
    if [ -f "$MYSQL_BIN" ]; then
        "$MYSQL_BIN" --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" --password="$DB_PASS" \
            "$DB_NAME" < "$EXTRACTED_DIR/database.sql"

        if [ $? -eq 0 ]; then
            echo "✓ Database restored successfully"
        else
            echo "✗ Database restore failed!"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    else
        echo "✗ mysql not found at $MYSQL_BIN"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
else
    echo "⚠ database.sql not found in backup, skipping..."
fi

# Restore images
echo ""
echo "[3/4] Restoring uploaded files..."
if [ -d "$EXTRACTED_DIR/images" ]; then
    # Backup existing images first
    if [ -d "$WIKI_DIR/images" ]; then
        echo "  Backing up existing images to images.old..."
        mv "$WIKI_DIR/images" "$WIKI_DIR/images.old.$(date +%Y%m%d_%H%M%S)"
    fi

    cp -R "$EXTRACTED_DIR/images" "$WIKI_DIR/images"
    echo "✓ Uploaded files restored"
else
    echo "⚠ images directory not found in backup, skipping..."
fi

# Restore LocalSettings.php (optional, with confirmation)
echo ""
echo "[4/4] Restoring configuration..."
if [ -f "$EXTRACTED_DIR/LocalSettings.php" ]; then
    read -p "Do you want to restore LocalSettings.php? (yes/no): " restore_config

    if [ "$restore_config" = "yes" ]; then
        # Backup existing config
        if [ -f "$WIKI_DIR/LocalSettings.php" ]; then
            cp "$WIKI_DIR/LocalSettings.php" "$WIKI_DIR/LocalSettings.php.backup.$(date +%Y%m%d_%H%M%S)"
            echo "  Existing config backed up"
        fi

        cp "$EXTRACTED_DIR/LocalSettings.php" "$WIKI_DIR/LocalSettings.php"
        echo "✓ Configuration restored"
    else
        echo "  Configuration restore skipped"
    fi
else
    echo "⚠ LocalSettings.php not found in backup, skipping..."
fi

# Cleanup
echo ""
echo "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

echo ""
echo "================================================"
echo "Restore completed successfully!"
echo "================================================"
echo ""
echo "Your wiki has been restored from: $BACKUP_FILE"
echo ""
echo "Note: If you restored LocalSettings.php, verify the database"
echo "credentials and paths are correct for your current environment."
echo ""
