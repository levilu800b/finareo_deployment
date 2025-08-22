#!/bin/bash

# =============================================================================
# LiveLens Media-Optimized VPS Setup Script
# Optimized for Hostinger VPS and large video uploads
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅${NC} $1"; }
warning() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌${NC} $1"; }

# Configuration
DOMAIN=${1:-localhost}
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
MYSQL_PASSWORD=$(openssl rand -base64 32)
DJANGO_SECRET_KEY=$(openssl rand -base64 50)

if [ -z "$1" ]; then
    warning "⚠️  No domain provided. Using localhost for development."
    warning "For production, run: ./setup-media-vps.sh yourdomain.com"
fi

log "🚀 Setting up LiveLens on Hostinger VPS..."
log "Domain: $DOMAIN"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log "This script needs to be run as root for initial setup"
    exit 1
fi

# Step 1: Update system and install dependencies
log "📦 Step 1: Installing system dependencies for Hostinger VPS..."

# Hostinger VPS often comes with some packages pre-installed
apt update && apt upgrade -y

# Install essential packages (optimized for Hostinger)
apt install -y \
    curl \
    wget \
    git \
    htop \
    ufw \
    fail2ban \
    nginx \
    certbot \
    python3-certbot-nginx \
    docker.io \
    docker-compose-plugin \
    python3 \
    python3-pip \
    mysql-client-core-8.0 \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install latest Docker Compose (Hostinger compatibility)
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install FFmpeg for video processing (latest version)
apt install -y \
    ffmpeg \
    imagemagick \
    libmagic1

# Install Node.js and Yarn (for frontend builds)
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs

# Install Yarn
npm install -g yarn

success "✅ System dependencies installed"

# Step 2: Configure firewall
log "🔒 Step 2: Configuring firewall..."

ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

success "✅ Firewall configured"

# Step 3: Configure Docker
log "🐳 Step 3: Configuring Docker..."

systemctl enable docker
systemctl start docker

# Add current user to docker group (if not root)
if [ "$SUDO_USER" ]; then
    usermod -aG docker $SUDO_USER
fi

success "✅ Docker configured"

# Step 4: Optimize system for media processing
log "⚡ Step 4: Optimizing system for media processing..."

# Increase file limits for large uploads
cat >> /etc/security/limits.conf << EOF
* soft nofile 65536
* hard nofile 65536
* soft nproc 4096
* hard nproc 4096
EOF

# Optimize kernel parameters
cat >> /etc/sysctl.conf << EOF
# Network optimizations
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# File system optimizations
fs.file-max = 2097152
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF

sysctl -p

success "✅ System optimized for media processing"

# Step 5: Create application directory and user
log "📁 Step 5: Setting up application environment..."

# Create app directory
mkdir -p /opt/livelens
cd /opt/livelens

# Clone or copy deployment files
if [ ! -f "docker-compose-media.yml" ]; then
    log "Creating Docker Compose configuration..."
    
    # Create basic directory structure
    mkdir -p {docker/nginx,docker/backend,docker/frontend,docker/media-processor,docker/mysql,docker/redis}
    
    log "Please copy your deployment files to /opt/livelens/"
    log "Required files: docker-compose-media.yml, docker/ directory, .env.production"
fi

success "✅ Application environment ready"

# Step 6: Generate environment file
log "🔧 Step 6: Generating environment configuration..."

cat > .env << EOF
# =============================================================================
# Production Environment Variables for Media-Optimized LiveLens
# =============================================================================

# Database Configuration
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=livelens_prod
MYSQL_USER=livelens
MYSQL_PASSWORD=$MYSQL_PASSWORD

# Django Configuration
DJANGO_SECRET_KEY=$DJANGO_SECRET_KEY
DJANGO_ALLOWED_HOSTS=$DOMAIN,www.$DOMAIN,localhost
DJANGO_DEBUG=False

# API and Frontend URLs
VITE_API_URL=https://$DOMAIN/api
VITE_MEDIA_URL=https://$DOMAIN/media
VITE_APP_TITLE=LiveLens

# CORS and CSRF Settings
CORS_ALLOWED_ORIGINS=https://$DOMAIN,https://www.$DOMAIN
CSRF_TRUSTED_ORIGINS=https://$DOMAIN,https://www.$DOMAIN

# Upload Configuration
MAX_UPLOAD_SIZE=10737418240
UPLOAD_CHUNK_SIZE=8388608
VIDEO_PROCESSING_ENABLED=True
VIDEO_QUALITY_PROFILES=360p,480p,720p,1080p

# Cloudflare R2 Configuration (Recommended for Hostinger VPS)
USE_CLOUDFLARE_R2=True
CLOUDFLARE_R2_ENDPOINT=https://your-account-id.r2.cloudflarestorage.com
CLOUDFLARE_R2_ACCESS_KEY=your-r2-access-key
CLOUDFLARE_R2_SECRET_KEY=your-r2-secret-key
CLOUDFLARE_R2_BUCKET=livelens-media
CLOUDFLARE_R2_PUBLIC_URL=https://media.$DOMAIN

# Email Configuration (Hostinger SMTP recommended)
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.hostinger.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@$DOMAIN
EMAIL_HOST_PASSWORD=your-email-password
DEFAULT_FROM_EMAIL=noreply@$DOMAIN

# Redis Configuration
REDIS_URL=redis://redis:6379/1

# Environment
ENVIRONMENT=production
EOF

success "✅ Environment configuration generated"

# Step 7: Generate SSL certificates (if domain provided and not localhost)
if [ "$DOMAIN" != "localhost" ]; then
    log "🔒 Step 7: Setting up SSL certificates..."
    
    # Create nginx directory for SSL
    mkdir -p docker/nginx/ssl
    
    # Generate self-signed certificates for initial setup
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout docker/nginx/ssl/nginx.key \
        -out docker/nginx/ssl/nginx.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"
    
    log "Self-signed certificates generated."
    log "After DNS is configured, run: certbot --nginx -d $DOMAIN -d www.$DOMAIN"
    
    success "✅ SSL certificates ready"
else
    log "🔒 Step 7: Skipping SSL setup for localhost"
    
    # Create dummy certificates for localhost
    mkdir -p docker/nginx/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout docker/nginx/ssl/nginx.key \
        -out docker/nginx/ssl/nginx.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
fi

# Step 8: Create necessary directories and set permissions
log "📂 Step 8: Creating data directories..."

mkdir -p {data/mysql,data/redis,data/uploads,data/processing,data/static,data/logs,data/nginx-cache}
chown -R 1000:1000 data/

success "✅ Data directories created"

# Step 9: Configure monitoring
log "📊 Step 9: Setting up basic monitoring..."

# Create monitoring script
cat > monitor-media.sh << 'EOF'
#!/bin/bash

# Check Docker services
if ! docker compose -f docker-compose-media.yml ps | grep -q "Up"; then
    echo "Services are down, restarting..."
    docker compose -f docker-compose-media.yml up -d
fi

# Check disk space
DISK_USAGE=$(df /opt/livelens | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "Disk space is getting low: ${DISK_USAGE}%"
    # Clean up old processed files
    find data/processing -name "*.tmp" -mtime +1 -delete
    docker system prune -f
fi

# Check memory usage
MEMORY_USAGE=$(free | grep Mem | awk '{print ($3/$2) * 100.0}' | cut -d. -f1)
if [ $MEMORY_USAGE -gt 90 ]; then
    echo "Memory usage is high: ${MEMORY_USAGE}%"
    # Restart media processor if memory is high
    docker compose -f docker-compose-media.yml restart media-processor
fi

# Check upload directory size
UPLOAD_SIZE=$(du -sh data/uploads | cut -f1)
echo "Upload directory size: $UPLOAD_SIZE"

# Check processing queue
PROCESSING_COUNT=$(ls data/processing/*.tmp 2>/dev/null | wc -l)
echo "Files in processing queue: $PROCESSING_COUNT"
EOF

chmod +x monitor-media.sh

# Add to crontab (run every 5 minutes)
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/livelens/monitor-media.sh") | crontab -

success "✅ Monitoring configured"

# Step 10: Create backup script
log "💾 Step 10: Setting up backup system..."

cat > backup-media.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
docker compose -f docker-compose-media.yml exec -T mysql mysqldump -u root -p$MYSQL_ROOT_PASSWORD livelens_prod > $BACKUP_DIR/db_backup_$DATE.sql

# Backup configuration
tar -czf $BACKUP_DIR/config_backup_$DATE.tar.gz .env docker/ 

# Keep only last 7 days of backups
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

chmod +x backup-media.sh

# Add to crontab (daily at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/livelens/backup-media.sh") | crontab -

success "✅ Backup system configured"

# Step 11: Generate final instructions
log "📋 Step 11: Generating setup instructions..."

cat > SETUP_COMPLETE.md << EOF
# 🎉 LiveLens Media VPS Setup Complete!

## Server Information
- **Domain**: $DOMAIN
- **Install Date**: $(date)
- **Location**: /opt/livelens

## Database Credentials
- **Root Password**: $MYSQL_ROOT_PASSWORD
- **User**: livelens
- **Password**: $MYSQL_PASSWORD
- **Database**: livelens_prod

## Next Steps

### 1. Deploy Application
\`\`\`bash
cd /opt/livelens

# Copy your deployment files here
# Then start the services
docker compose -f docker-compose-media.yml up -d
\`\`\`

### 2. Configure Cloudflare R2 (Recommended)
Update these values in .env:
\`\`\`bash
CLOUDFLARE_R2_ENDPOINT=https://your-account-id.r2.cloudflarestorage.com
CLOUDFLARE_R2_ACCESS_KEY=your-r2-access-key
CLOUDFLARE_R2_SECRET_KEY=your-r2-secret-key
CLOUDFLARE_R2_BUCKET=livelens-media
\`\`\`

### 3. Configure DNS (if using real domain)
Point these records to this server:
\`\`\`
A    $DOMAIN         $(curl -s ifconfig.me)
A    www.$DOMAIN     $(curl -s ifconfig.me)
\`\`\`

### 4. Setup Let's Encrypt SSL (for real domain)
\`\`\`bash
certbot --nginx -d $DOMAIN -d www.$DOMAIN
\`\`\`

### 5. Configure Email
Update email settings in .env with your SMTP provider.

## Management Commands

### View logs
\`\`\`bash
docker compose -f docker-compose-media.yml logs -f
\`\`\`

### Restart services
\`\`\`bash
docker compose -f docker-compose-media.yml restart
\`\`\`

### Check media processing queue
\`\`\`bash
docker compose -f docker-compose-media.yml logs celery-worker
\`\`\`

### Monitor resources
\`\`\`bash
htop
docker stats
\`\`\`

## File Locations
- **Application**: /opt/livelens
- **Data**: /opt/livelens/data/
- **Backups**: /opt/backups/
- **Logs**: /opt/livelens/data/logs/

## Support
- Monitor script: ./monitor-media.sh
- Backup script: ./backup-media.sh
- Environment: .env
- Compose file: docker-compose-media.yml

🚀 Your media-optimized LiveLens VPS is ready!
EOF

success "✅ Setup instructions generated"

echo
echo "=================================================================================="
echo "🎉 LIVELENS MEDIA VPS SETUP COMPLETE!"
echo "=================================================================================="
echo
echo "✅ System optimized for large video uploads and streaming"
echo "✅ Docker and Docker Compose installed"
echo "✅ Firewall configured (ports 80, 443, 22)"
echo "✅ SSL certificates generated"
echo "✅ Environment file created (.env)"
echo "✅ Monitoring and backup scripts installed"
echo "✅ FFmpeg and media processing tools ready"
echo
echo "📋 Next Steps:"
echo "   1. Copy your deployment files to /opt/livelens/"
echo "   2. Configure Cloudflare R2 credentials in .env"
echo "   3. Update DNS records to point to this server"
echo "   4. Run: docker compose -f docker-compose-media.yml up -d"
echo "   5. Setup Let's Encrypt: certbot --nginx -d $DOMAIN"
echo
echo "🔑 Database Credentials:"
echo "   Root Password: $MYSQL_ROOT_PASSWORD"
echo "   User Password: $MYSQL_PASSWORD"
echo
echo "📖 Read SETUP_COMPLETE.md for detailed instructions"
echo
success "🎬 Ready to handle 2-hour videos without breaking the bank!"
