#!/bin/bash
# ===========================================
# Finareo Database Backup Script
# ===========================================
# Usage: ./backup.sh [daily|weekly|manual]
# Backups are stored in /opt/finareo/backups

set -e

BACKUP_DIR="/opt/finareo/backups"
DEPLOY_DIR="/opt/finareo/deployment"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_TYPE=${1:-manual}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Load environment variables
if [ -f "$DEPLOY_DIR/.env" ]; then
    source "$DEPLOY_DIR/.env"
else
    log_error ".env file not found!"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR/$BACKUP_TYPE"

# ===========================================
# MySQL Backup
# ===========================================
backup_mysql() {
    log_info "Backing up MySQL database..."
    
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_TYPE/mysql_${DATE}.sql.gz"
    
    docker exec finareo-mysql mysqldump \
        -u"$MYSQL_USER" \
        -p"$MYSQL_PASSWORD" \
        --single-transaction \
        --routines \
        --triggers \
        "$MYSQL_DATABASE" | gzip > "$BACKUP_FILE"
    
    if [ -f "$BACKUP_FILE" ]; then
        SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log_info "MySQL backup complete: $BACKUP_FILE ($SIZE)"
    else
        log_error "MySQL backup failed!"
        exit 1
    fi
}

# ===========================================
# Redis Backup (RDB snapshot)
# ===========================================
backup_redis() {
    log_info "Backing up Redis..."
    
    # Trigger Redis save
    docker exec finareo-redis redis-cli BGSAVE
    sleep 2
    
    # Copy RDB file
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_TYPE/redis_${DATE}.rdb"
    docker cp finareo-redis:/data/dump.rdb "$BACKUP_FILE" 2>/dev/null || true
    
    if [ -f "$BACKUP_FILE" ]; then
        SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log_info "Redis backup complete: $BACKUP_FILE ($SIZE)"
    else
        log_warn "Redis backup skipped (no data or empty)"
    fi
}

# ===========================================
# Cleanup Old Backups
# ===========================================
cleanup_backups() {
    log_info "Cleaning up old backups..."
    
    # Keep last 7 daily backups
    find "$BACKUP_DIR/daily" -name "*.sql.gz" -mtime +7 -delete 2>/dev/null || true
    find "$BACKUP_DIR/daily" -name "*.rdb" -mtime +7 -delete 2>/dev/null || true
    
    # Keep last 4 weekly backups
    find "$BACKUP_DIR/weekly" -name "*.sql.gz" -mtime +28 -delete 2>/dev/null || true
    find "$BACKUP_DIR/weekly" -name "*.rdb" -mtime +28 -delete 2>/dev/null || true
    
    # Keep last 10 manual backups
    ls -t "$BACKUP_DIR/manual/"*.sql.gz 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
    
    log_info "Cleanup complete"
}

# ===========================================
# List Backups
# ===========================================
list_backups() {
    echo ""
    echo "=========================================="
    echo "Available Backups"
    echo "=========================================="
    
    for type in daily weekly manual; do
        if [ -d "$BACKUP_DIR/$type" ]; then
            COUNT=$(ls -1 "$BACKUP_DIR/$type"/*.sql.gz 2>/dev/null | wc -l)
            if [ "$COUNT" -gt 0 ]; then
                echo ""
                echo "[$type] - $COUNT backup(s)"
                ls -lh "$BACKUP_DIR/$type"/*.sql.gz 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
            fi
        fi
    done
    echo ""
}

# ===========================================
# Restore Backup
# ===========================================
restore_backup() {
    BACKUP_FILE=$1
    
    if [ -z "$BACKUP_FILE" ]; then
        log_error "Please specify backup file to restore"
        list_backups
        exit 1
    fi
    
    if [ ! -f "$BACKUP_FILE" ]; then
        log_error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi
    
    log_warn "⚠️  This will OVERWRITE the current database!"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "Restore cancelled"
        exit 0
    fi
    
    log_info "Restoring from $BACKUP_FILE..."
    
    gunzip -c "$BACKUP_FILE" | docker exec -i finareo-mysql mysql \
        -u"$MYSQL_USER" \
        -p"$MYSQL_PASSWORD" \
        "$MYSQL_DATABASE"
    
    log_info "Restore complete!"
}

# ===========================================
# Main
# ===========================================
case "$1" in
    daily|weekly|manual|"")
        backup_mysql
        backup_redis
        cleanup_backups
        log_info "✅ Backup complete!"
        ;;
    list)
        list_backups
        ;;
    restore)
        restore_backup "$2"
        ;;
    *)
        echo "Usage: $0 [daily|weekly|manual|list|restore <file>]"
        exit 1
        ;;
esac
