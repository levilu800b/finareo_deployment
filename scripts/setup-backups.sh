#!/bin/bash
# ===========================================
# Setup Automated Backups via Cron
# ===========================================
# Run this script once on your VPS to enable automated backups

SCRIPT_DIR="/opt/finareo/deployment/scripts"

echo "Setting up automated database backups..."

# Create cron jobs
(crontab -l 2>/dev/null | grep -v "finareo.*backup"; cat << EOF
# Finareo Database Backups
# Daily backup at 2:00 AM
0 2 * * * $SCRIPT_DIR/backup.sh daily >> /var/log/finareo-backup.log 2>&1

# Weekly backup on Sundays at 3:00 AM
0 3 * * 0 $SCRIPT_DIR/backup.sh weekly >> /var/log/finareo-backup.log 2>&1
EOF
) | crontab -

echo "✅ Automated backups configured!"
echo ""
echo "Backup schedule:"
echo "  - Daily:  Every day at 2:00 AM (kept for 7 days)"
echo "  - Weekly: Every Sunday at 3:00 AM (kept for 4 weeks)"
echo ""
echo "Manual backup commands:"
echo "  ./scripts/backup.sh manual    # Create manual backup"
echo "  ./scripts/backup.sh list      # List all backups"
echo "  ./scripts/backup.sh restore <file>  # Restore from backup"
echo ""
echo "Logs: /var/log/finareo-backup.log"
