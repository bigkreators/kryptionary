#!/bin/bash

# MediaWiki Backup Script for Kryptionary
# This script backs up both the MySQL database and uploaded files

# Configuration
WIKI_DIR="/Applications/MAMP/htdocs/kryptionary"
BACKUP_DIR="$WIKI_DIR/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="kryptionary_backup_$DATE"

# Database configuration (from LocalSettings.php)
DB_NAME="kryptionary_db"
DB_USER="root"
DB_PASS="root"
DB_HOST="localhost"
DB_PORT="8889"

# MAMP MySQL path (adjust if needed)
MYSQL_BIN="/Applications/MAMP/Library/bin/mysql80/bin/mysqldump"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

echo "================================================"
echo "Starting Kryptionary Wiki Backup"
echo "================================================"
echo "Backup timestamp: $DATE"
echo ""

# 1. Backup the database
echo "[1/3] Backing up MySQL database..."
if [ -f "$MYSQL_BIN" ]; then
    "$MYSQL_BIN" --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" --password="$DB_PASS" \
        --single-transaction --quick --lock-tables=false \
        "$DB_NAME" > "$BACKUP_DIR/$BACKUP_NAME/database.sql"

    if [ $? -eq 0 ]; then
        echo "✓ Database backup completed successfully"
        echo "  Size: $(du -h "$BACKUP_DIR/$BACKUP_NAME/database.sql" | cut -f1)"
    else
        echo "✗ Database backup failed!"
        exit 1
    fi
else
    echo "✗ mysqldump not found at $MYSQL_BIN"
    echo "  Please update MYSQL_BIN path in the script"
    exit 1
fi

# 2. Backup uploaded files (images directory)
echo ""
echo "[2/3] Backing up uploaded files..."
if [ -d "$WIKI_DIR/images" ]; then
    cp -R "$WIKI_DIR/images" "$BACKUP_DIR/$BACKUP_NAME/images"
    echo "✓ Uploaded files backup completed"
    echo "  Size: $(du -sh "$BACKUP_DIR/$BACKUP_NAME/images" | cut -f1)"
else
    echo "⚠ Images directory not found, skipping..."
fi

# 3. Backup LocalSettings.php (configuration)
echo ""
echo "[3/3] Backing up configuration..."
if [ -f "$WIKI_DIR/LocalSettings.php" ]; then
    cp "$WIKI_DIR/LocalSettings.php" "$BACKUP_DIR/$BACKUP_NAME/LocalSettings.php"
    echo "✓ Configuration backup completed"
else
    echo "⚠ LocalSettings.php not found, skipping..."
fi

# Create compressed archive
echo ""
echo "Creating compressed archive..."
cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"

if [ $? -eq 0 ]; then
    echo "✓ Archive created: ${BACKUP_NAME}.tar.gz"
    echo "  Size: $(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)"

    # Remove uncompressed backup directory
    rm -rf "$BACKUP_NAME"
    echo "✓ Cleaned up temporary files"
else
    echo "✗ Archive creation failed!"
    exit 1
fi

# Summary
echo ""
echo "================================================"
echo "Backup completed successfully!"
echo "================================================"
echo "Backup location: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
echo ""
echo "To restore this backup:"
echo "  1. Extract: tar -xzf ${BACKUP_NAME}.tar.gz"
echo "  2. Import database: mysql -u root -p kryptionary_db < database.sql"
echo "  3. Restore images: cp -R images/* /path/to/wiki/images/"
echo "  4. Restore config: cp LocalSettings.php /path/to/wiki/"
echo ""

# List all backups
echo "All backups:"
ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "  No previous backups found"
