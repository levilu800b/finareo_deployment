#!/bin/bash
# Database backup script for LiveLens

BACKUP_DIR="/opt/livelens/backups"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="livelens_backup_${DATE}.sql"

# Create backup directory
mkdir -p ${BACKUP_DIR}

# Create database backup
docker exec livelens_mysql mysqldump -u root -p${MYSQL_ROOT_PASSWORD} ${MYSQL_DATABASE} > ${BACKUP_DIR}/${BACKUP_FILE}

# Compress backup
gzip ${BACKUP_DIR}/${BACKUP_FILE}

# Keep only last 7 days of backups
find ${BACKUP_DIR} -name "*.gz" -mtime +7 -delete

echo "Backup completed: ${BACKUP_FILE}.gz"
