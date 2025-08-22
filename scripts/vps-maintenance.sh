#!/bin/bash
# VPS Maintenance Script - Clean up Docker to free disk space
# SAFE: This script only removes unused Docker images and cache
# It NEVER affects your database or running services

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[MAINTENANCE]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[INFO]${NC} $1"; }

log "🧹 Starting VPS maintenance - Docker cleanup"

# Show current disk usage
log "Current disk usage:"
df -h /

echo ""
warning "This script will remove:"
warning "  ✅ Unused Docker images"
warning "  ✅ Stopped containers"
warning "  ✅ Unused networks"
warning "  ✅ Build cache"
echo ""
warning "This script will NOT affect:"
warning "  🛡️  Database data"
warning "  🛡️  Running containers"
warning "  🛡️  Persistent volumes"
echo ""

# Show Docker disk usage before cleanup
log "Docker disk usage before cleanup:"
docker system df

echo ""
log "Cleaning up Docker images and cache..."

# Clean up Docker
docker system prune -a -f
docker builder prune -a -f

echo ""
success "✅ Docker cleanup completed!"

# Show Docker disk usage after cleanup
log "Docker disk usage after cleanup:"
docker system df

echo ""
log "Updated disk usage:"
df -h /

success "🎉 VPS maintenance completed successfully!"
log "💡 Run this script monthly or when disk space gets low"
