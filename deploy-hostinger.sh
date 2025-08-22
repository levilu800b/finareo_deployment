#!/bin/bash

# =============================================================================
# LiveLens Hostinger VPS Deployment Script
# Domain: livelens.space
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
DOMAIN="livelens.space"
DEPLOY_DIR="/opt/livelens"

# Load configuration from config.env if it exists
if [ -f "config.env" ]; then
    log "📋 Loading configuration from config.env..."
    source config.env
fi

# Prompt for GitHub username if not provided
if [ -z "$GITHUB_USER" ]; then
    read -p "Enter your GitHub username: " GITHUB_USER
fi

FRONTEND_REPO="git@github.com-frontend:${GITHUB_USER}/LiveLens_UI.git"
BACKEND_REPO="git@github.com-backend:${GITHUB_USER}/LiveLens_Backend.git"
DEPLOYMENT_REPO="git@github.com-deployment:${GITHUB_USER}/livelens_deployment.git"

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    error "Please run this script as root or with sudo"
    exit 1
fi

log "🚀 Starting LiveLens deployment on Hostinger VPS..."
log "Domain: $DOMAIN"

# Step 1: Update system
log "📦 Step 1: Updating system..."
apt update && apt upgrade -y

# Step 2: Install required packages
log "📋 Step 2: Installing required packages..."
apt install -y curl wget git docker.io docker-compose-plugin nginx certbot python3-certbot-nginx ufw fail2ban

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Step 3: Configure firewall
log "🔒 Step 3: Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Step 4: Create deployment directory
log "📁 Step 4: Setting up deployment directory and SSH keys..."
mkdir -p $DEPLOY_DIR
cd $DEPLOY_DIR

# Generate SSH key for GitHub access if it doesn't exist
if [ ! -f ~/.ssh/id_rsa ]; then
    log "🔑 Generating SSH key for GitHub access..."
    ssh-keygen -t rsa -b 4096 -C "deploy@livelens.space" -f ~/.ssh/id_rsa -N ""
    
    echo ""
    echo "=========================================="
    echo "🔑 SSH PUBLIC KEY FOR GITHUB DEPLOY KEYS"
    echo "=========================================="
    echo "Copy this public key and add it as a deploy key to ALL THREE repositories:"
    echo ""
    cat ~/.ssh/id_rsa.pub
    echo ""
    echo "To add deploy keys:"
    echo "1. Go to each GitHub repository"
    echo "2. Settings > Deploy keys > Add deploy key"
    echo "3. Paste the key above"
    echo "4. Check 'Allow write access' if you want auto-deployment"
    echo ""
    echo "Repositories to add this key to:"
    echo "- https://github.com/${GITHUB_USER}/LiveLens_UI"
    echo "- https://github.com/${GITHUB_USER}/LiveLens_Backend" 
    echo "- https://github.com/${GITHUB_USER}/livelens_deployment"
    echo "=========================================="
    echo ""
    read -p "Press Enter after adding the deploy key to all repositories..."
fi

# Add GitHub to known hosts
ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>/dev/null || true

# Step 5: Clone repositories if not exists
log "📥 Step 5: Cloning repositories..."

# Clone deployment repository
if [ ! -d "livelens_deployment" ]; then
    log "📥 Cloning deployment repository..."
    git clone $DEPLOYMENT_REPO livelens_deployment
else
    log "📥 Updating deployment repository..."
    cd livelens_deployment && git pull origin master && cd ..
fi

# Clone backend repository
if [ ! -d "LiveLens_Backend" ]; then
    log "📥 Cloning backend repository..."
    git clone $BACKEND_REPO LiveLens_Backend
else
    log "📥 Updating backend repository..."
    cd LiveLens_Backend && git pull origin master && cd ..
fi

# Clone frontend repository  
if [ ! -d "LiveLens_UI" ]; then
    log "📥 Cloning frontend repository..."
    git clone $FRONTEND_REPO LiveLens_UI
else
    log "📥 Updating frontend repository..."
    cd LiveLens_UI && git pull origin master && cd ..
fi

success "✅ All repositories cloned/updated successfully"

# Step 6: Navigate to deployment directory
cd livelens_deployment

# Step 7: Generate secure passwords and collect configuration
log "🔐 Step 7: Generating secure credentials and collecting configuration..."
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
MYSQL_PASSWORD=$(openssl rand -base64 32)
DJANGO_SECRET_KEY=$(openssl rand -base64 50 | tr -d '\n')
ADMIN_PASSWORD=$(openssl rand -base64 16)

# Collect email configuration
echo ""
echo "📧 Email Configuration Setup:"
echo "For production email notifications, please provide SMTP settings."
echo "You can skip this now and configure later in .env.production"
echo ""

# Use existing values if available, otherwise prompt
if [ -z "$EMAIL_HOST" ]; then
    read -p "Email Host (e.g., smtp.gmail.com): " EMAIL_HOST
fi

if [ -z "$EMAIL_PORT" ]; then
    read -p "Email Port (e.g., 587): " EMAIL_PORT
fi

if [ -z "$EMAIL_USER" ]; then
    read -p "Email User (your-email@gmail.com): " EMAIL_USER
fi

if [ -z "$EMAIL_PASSWORD" ]; then
    read -s -p "Email Password (app password): " EMAIL_PASSWORD
    echo ""
fi

if [ -z "$DEFAULT_FROM_EMAIL" ]; then
    read -p "Default From Email (e.g., noreply@livelens.space): " DEFAULT_FROM_EMAIL
fi

# Set defaults if empty
EMAIL_HOST=${EMAIL_HOST:-smtp.gmail.com}
EMAIL_PORT=${EMAIL_PORT:-587}
DEFAULT_FROM_EMAIL=${DEFAULT_FROM_EMAIL:-noreply@livelens.space}

# Step 8: Create production environment file
log "⚙️ Step 8: Creating production environment file..."

# Backup existing .env.production if it exists
if [ -f ".env.production" ]; then
    log "📋 Backing up existing .env.production..."
    cp .env.production .env.production.backup.$(date +%Y%m%d_%H%M%S)
    
    # Load existing values to preserve important settings
    if grep -q "EMAIL_HOST_USER=" .env.production; then
        EXISTING_EMAIL_USER=$(grep "EMAIL_HOST_USER=" .env.production | cut -d'=' -f2)
        EMAIL_USER=${EMAIL_USER:-$EXISTING_EMAIL_USER}
    fi
    
    if grep -q "EMAIL_HOST_PASSWORD=" .env.production; then
        EXISTING_EMAIL_PASSWORD=$(grep "EMAIL_HOST_PASSWORD=" .env.production | cut -d'=' -f2 | tr -d '"')
        EMAIL_PASSWORD=${EMAIL_PASSWORD:-$EXISTING_EMAIL_PASSWORD}
    fi
    
    if grep -q "GOOGLE_AI_API_KEY=" .env.production; then
        EXISTING_GOOGLE_API_KEY=$(grep "GOOGLE_AI_API_KEY=" .env.production | cut -d'=' -f2)
    fi
    
    if grep -q "MYSQL_ROOT_PASSWORD=" .env.production; then
        EXISTING_MYSQL_ROOT_PASSWORD=$(grep "MYSQL_ROOT_PASSWORD=" .env.production | cut -d'=' -f2)
        MYSQL_ROOT_PASSWORD=${EXISTING_MYSQL_ROOT_PASSWORD}
    fi
    
    if grep -q "MYSQL_PASSWORD=" .env.production; then
        EXISTING_MYSQL_PASSWORD=$(grep "MYSQL_PASSWORD=" .env.production | cut -d'=' -f2)
        MYSQL_PASSWORD=${EXISTING_MYSQL_PASSWORD}
    fi
    
    if grep -q "DJANGO_SECRET_KEY=" .env.production; then
        EXISTING_DJANGO_SECRET=$(grep "DJANGO_SECRET_KEY=" .env.production | cut -d'=' -f2)
        DJANGO_SECRET_KEY=${EXISTING_DJANGO_SECRET}
    fi
    
    if grep -q "DJANGO_SUPERUSER_PASSWORD=" .env.production; then
        EXISTING_ADMIN_PASSWORD=$(grep "DJANGO_SUPERUSER_PASSWORD=" .env.production | cut -d'=' -f2)
        ADMIN_PASSWORD=${EXISTING_ADMIN_PASSWORD}
    fi
fi

cat > .env.production << EOF
# =============================================================================
# LiveLens Production Environment Configuration
# Generated on $(date)
# =============================================================================

# Domain Configuration
DOMAIN_NAME=livelens.space
ALLOWED_HOSTS=livelens.space,www.livelens.space,localhost

# Database Configuration
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=livelens_prod
MYSQL_USER=livelens_user
MYSQL_PASSWORD=$MYSQL_PASSWORD
MYSQL_HOST=mysql
MYSQL_PORT=3306

# Django Configuration
DJANGO_SECRET_KEY=$DJANGO_SECRET_KEY
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=livelens.space,www.livelens.space,localhost
DJANGO_SETTINGS_MODULE=app.settings

# API and Frontend URLs
VITE_API_URL=https://livelens.space/api
VITE_MEDIA_URL=https://livelens.space/media
VITE_APP_TITLE=LiveLens
FRONTEND_URL=https://livelens.space
BACKEND_URL=https://livelens.space/api

# Google AI API Key (preserve existing if available)
${EXISTING_GOOGLE_API_KEY:+GOOGLE_AI_API_KEY=$EXISTING_GOOGLE_API_KEY}

# CORS and CSRF Settings
CORS_ALLOWED_ORIGINS=https://livelens.space,https://www.livelens.space
CSRF_TRUSTED_ORIGINS=https://livelens.space,https://www.livelens.space
CORS_ALLOW_CREDENTIALS=true

# Redis Configuration
REDIS_URL=redis://redis:6379/1
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_DB=1

# Email Configuration
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=$EMAIL_HOST
EMAIL_PORT=$EMAIL_PORT
EMAIL_USE_TLS=True
EMAIL_HOST_USER=$EMAIL_USER
EMAIL_HOST_PASSWORD=$EMAIL_PASSWORD
DEFAULT_FROM_EMAIL=$DEFAULT_FROM_EMAIL

# Media and Static Files
STATIC_URL=/static/
MEDIA_URL=/media/
STATIC_ROOT=/app/staticfiles
MEDIA_ROOT=/app/media

# Upload Configuration
MAX_UPLOAD_SIZE=10737418240
UPLOAD_CHUNK_SIZE=8388608
FILE_UPLOAD_MAX_MEMORY_SIZE=10485760
DATA_UPLOAD_MAX_MEMORY_SIZE=10485760

# Video Processing
VIDEO_PROCESSING_ENABLED=True
VIDEO_QUALITY_PROFILES=360p,480p,720p,1080p
FFMPEG_PATH=/usr/bin/ffmpeg

# Security Settings
SECURE_SSL_REDIRECT=True
SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True
SECURE_BROWSER_XSS_FILTER=True
SECURE_CONTENT_TYPE_NOSNIFF=True

# Admin Configuration
DJANGO_SUPERUSER_EMAIL=admin@$DOMAIN
DJANGO_SUPERUSER_USERNAME=admin
DJANGO_SUPERUSER_PASSWORD=$ADMIN_PASSWORD

# Logging
LOG_LEVEL=INFO
DJANGO_LOG_LEVEL=INFO

# Environment
ENVIRONMENT=production
EOF

# Step 9: Set up SSL certificate
log "🔒 Step 9: Setting up SSL certificate..."
# Stop nginx if running
systemctl stop nginx || true

# Get SSL certificate
certbot certonly --standalone -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN

# Step 10: Build and start services
log "🐳 Step 10: Building and starting Docker services..."
docker-compose -f docker-compose.hostinger.yml down || true
docker-compose -f docker-compose.hostinger.yml build --no-cache
docker-compose -f docker-compose.hostinger.yml up -d

# Step 11: Wait for services to be ready
log "⏳ Waiting for services to start..."
sleep 30

# Step 12: Check service status
log "🔍 Checking service status..."
docker-compose -f docker-compose.hostinger.yml ps

# Step 13: Display credentials
success "✅ Deployment completed successfully!"
echo ""
echo "=========================================="
echo "🔑 IMPORTANT: Save these credentials!"
echo "=========================================="
echo "Domain: https://$DOMAIN"
echo "Admin Panel: https://$DOMAIN/admin/"
echo "Admin Username: admin"
echo "Admin Password: $ADMIN_PASSWORD"
echo "MySQL Root Password: $MYSQL_ROOT_PASSWORD"
echo "MySQL User Password: $MYSQL_PASSWORD"
echo "=========================================="
echo ""
warning "⚠️  Please save these credentials in a secure location!"
warning "⚠️  Update your email settings in .env.production"
echo ""

# Step 14: Set up automatic SSL renewal
log "🔄 Setting up automatic SSL renewal..."
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

success "🎉 LiveLens is now deployed and accessible at https://$DOMAIN"
log "📊 You can monitor the application logs with: docker-compose -f docker-compose.hostinger.yml logs -f"
