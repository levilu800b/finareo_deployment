#!/bin/bash
# ===========================================
# Finareo Deployment Script
# ===========================================
# Usage: ./deploy.sh [command]
# Commands: start, stop, restart, update, logs, status, ssl-init, backup, clone

set -e

# Configuration
DEPLOY_DIR="/opt/finareo"
DEPLOY_SRC="$DEPLOY_DIR/deployment"
BACKEND_SRC="$DEPLOY_DIR/backend-src"
COMPOSE_FILE="docker-compose.yml"
COMPOSE_PROD="docker-compose.prod.yml"
DOMAIN="api.finareo.com"

# GitHub repos (private)
GITHUB_USER="levilu800b"
BACKEND_REPO="git@github.com:${GITHUB_USER}/Finareo_Backend.git"
DEPLOYMENT_REPO="git@github.com:${GITHUB_USER}/finareo_deployment.git"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Navigate to deployment directory
cd "$DEPLOY_DIR"

# ===========================================
# Helper Functions
# ===========================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_env() {
    if [ ! -f .env ]; then
        log_error ".env file not found! Copy .env.example to .env and configure it."
        exit 1
    fi
}

# ===========================================
# Commands
# ===========================================
start() {
    check_env
    log_info "Starting Finareo services..."
    docker-compose -f $COMPOSE_FILE -f $COMPOSE_PROD up -d
    log_success "Services started!"
    status
}

stop() {
    log_info "Stopping Finareo services..."
    docker-compose -f $COMPOSE_FILE -f $COMPOSE_PROD down
    log_success "Services stopped!"
}

restart() {
    log_info "Restarting Finareo services..."
    docker-compose -f $COMPOSE_FILE -f $COMPOSE_PROD restart
    log_success "Services restarted!"
}

# Helper function to safely pull from git
git_safe_pull() {
    local dir="$1"
    local name="$2"
    cd "$dir"
    
    # Stash any local changes
    if [ -n "$(git status --porcelain)" ]; then
        log_warning "Stashing local changes in $name..."
        git stash push -m "Auto-stash before update $(date +%Y%m%d_%H%M%S)"
    fi
    
    # Get the default branch (master or main)
    local branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "master")
    
    # Pull from the correct branch
    git pull origin "$branch" || {
        log_error "Failed to pull $name from origin/$branch"
        return 1
    }
    
    log_success "Updated $name from origin/$branch"
}

update() {
    log_info "Updating Finareo..."
    
    # Pull latest deployment config
    log_info "Pulling latest deployment config..."
    git_safe_pull "$DEPLOY_SRC" "deployment"
    
    # Pull latest backend
    log_info "Pulling latest backend..."
    git_safe_pull "$BACKEND_SRC" "backend"
    
    # Copy backend source to deployment
    log_info "Copying backend source..."
    rm -rf "$DEPLOY_SRC/backend/src" "$DEPLOY_SRC/backend/pom.xml"
    mkdir -p "$DEPLOY_SRC/backend"
    cp -r "$BACKEND_SRC/src" "$DEPLOY_SRC/backend/"
    cp "$BACKEND_SRC/pom.xml" "$DEPLOY_SRC/backend/"
    
    # Rebuild and restart services
    cd "$DEPLOY_SRC"
    log_info "Rebuilding containers..."
    docker-compose -f $COMPOSE_FILE -f $COMPOSE_PROD build --no-cache backend
    docker-compose -f $COMPOSE_FILE -f $COMPOSE_PROD up -d
    
    # Wait for services to be healthy
    sleep 10
    
    # Cleanup old images
    log_info "Cleaning up old images..."
    docker image prune -f
    
    # Remove dangling images older than 24h
    docker image prune -a --filter "until=24h" -f 2>/dev/null || true
    
    log_success "Update complete!"
    status
}

# Update backend only
update_backend() {
    log_info "Updating backend only..."
    
    # Pull latest backend
    git_safe_pull "$BACKEND_SRC" "backend"
    cd "$BACKEND_SRC"
    
    # Copy backend source to deployment
    log_info "Copying backend source..."
    rm -rf "$DEPLOY_SRC/backend/src" "$DEPLOY_SRC/backend/pom.xml"
    mkdir -p "$DEPLOY_SRC/backend"
    cp -r "$BACKEND_SRC/src" "$DEPLOY_SRC/backend/"
    cp "$BACKEND_SRC/pom.xml" "$DEPLOY_SRC/backend/"
    
    # Rebuild and restart backend
    cd "$DEPLOY_SRC"
    log_info "Rebuilding backend container..."
    docker-compose -f $COMPOSE_FILE -f $COMPOSE_PROD build --no-cache backend
    docker-compose -f $COMPOSE_FILE -f $COMPOSE_PROD up -d backend
    
    log_success "Backend update complete!"
}

logs() {
    SERVICE=${2:-""}
    if [ -n "$SERVICE" ]; then
        docker-compose -f $COMPOSE_FILE logs -f $SERVICE
    else
        docker-compose -f $COMPOSE_FILE logs -f
    fi
}

status() {
    echo ""
    echo "=========================================="
    echo "Finareo Service Status"
    echo "=========================================="
    docker-compose -f $COMPOSE_FILE ps
    echo ""
    echo "Resource Usage:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
}

ssl_init() {
    log_info "Initializing SSL certificates with Let's Encrypt..."
    
    # Check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        log_error "Certbot is not installed. Run setup-vps.sh first."
        exit 1
    fi
    
    # Stop nginx if running
    docker-compose -f $COMPOSE_FILE stop nginx 2>/dev/null || true
    
    # Get certificates
    certbot certonly --standalone \
        -d $DOMAIN \
        -d www.$DOMAIN \
        --non-interactive \
        --agree-tos \
        --email admin@$DOMAIN
    
    # Copy certificates to deployment directory
    mkdir -p certbot/conf
    cp -rL /etc/letsencrypt/* certbot/conf/
    
    log_success "SSL certificates obtained!"
    
    # Start services
    start
}

ssl_renew() {
    log_info "Renewing SSL certificates..."
    docker-compose -f $COMPOSE_FILE run --rm certbot renew
    docker-compose -f $COMPOSE_FILE exec nginx nginx -s reload
    log_success "SSL certificates renewed!"
}

backup() {
    log_info "Creating backup..."
    BACKUP_DIR="/opt/finareo/backups"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    mkdir -p $BACKUP_DIR
    
    # Backup MySQL
    log_info "Backing up MySQL database..."
    docker-compose -f $COMPOSE_FILE exec -T mysql mysqldump \
        -u root -p"$MYSQL_ROOT_PASSWORD" \
        --all-databases > "$BACKUP_DIR/mysql_$TIMESTAMP.sql"
    
    # Compress backup
    gzip "$BACKUP_DIR/mysql_$TIMESTAMP.sql"
    
    # Keep only last 7 days of backups
    find $BACKUP_DIR -name "*.sql.gz" -mtime +7 -delete
    
    log_success "Backup created: $BACKUP_DIR/mysql_$TIMESTAMP.sql.gz"
}

clone_repos() {
    log_info "Cloning repositories from GitHub..."
    cd "$DEPLOY_DIR"
    
    # Clone deployment repo
    if [ ! -d "$DEPLOY_SRC" ]; then
        log_info "Cloning deployment repository..."
        git clone "$DEPLOYMENT_REPO" deployment
    else
        log_success "Deployment repo already exists"
    fi
    
    # Clone backend repo
    if [ ! -d "$BACKEND_SRC" ]; then
        log_info "Cloning backend repository..."
        git clone "$BACKEND_REPO" backend-src
    else
        log_success "Backend repo already exists"
    fi
    
    log_success "All repositories cloned!"
    echo ""
    echo "Next steps:"
    echo "  1. cd $DEPLOY_SRC"
    echo "  2. cp .env.example .env"
    echo "  3. nano .env  # Configure your environment"
    echo "  4. ./scripts/deploy.sh init"
}

init_deployment() {
    log_info "Initializing deployment..."
    
    # Check if repos exist
    if [ ! -d "$BACKEND_SRC" ]; then
        log_error "Backend repository not cloned. Run: ./deploy.sh clone"
        exit 1
    fi
    
    # Check .env
    if [ ! -f "$DEPLOY_SRC/.env" ]; then
        log_error ".env not configured. Copy .env.example to .env and configure it."
        exit 1
    fi
    
    cd "$DEPLOY_SRC"
    
    # Build frontend
    log_info "Building frontend..."
    cd "$FRONTEND_SRC"
    yarn install --frozen-lockfile
    yarn build
    
    # Copy frontend build
    log_info "Copying frontend build..."
    rm -rf "$DEPLOY_SRC/frontend/dist"
    mkdir -p "$DEPLOY_SRC/frontend"
    cp -r dist "$DEPLOY_SRC/frontend/"
    
    # Copy backend source
    log_info "Copying backend source..."
    rm -rf "$DEPLOY_SRC/backend/src" "$DEPLOY_SRC/backend/pom.xml"
    mkdir -p "$DEPLOY_SRC/backend"
    cp -r "$BACKEND_SRC/src" "$DEPLOY_SRC/backend/"
    cp "$BACKEND_SRC/pom.xml" "$DEPLOY_SRC/backend/"
    
    cd "$DEPLOY_SRC"
    
    # Build containers
    log_info "Building Docker containers..."
    docker-compose -f $COMPOSE_FILE -f $COMPOSE_PROD build
    
    log_success "Initialization complete!"
    echo ""
    echo "Next steps:"
    echo "  1. ./scripts/deploy.sh ssl-init  # Get SSL certificates"
    echo "  2. ./scripts/deploy.sh start     # Start services"
}

health() {
    log_info "Checking service health..."
    echo ""
    
    # Check backend health
    BACKEND_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/health || echo "000")
    if [ "$BACKEND_HEALTH" == "200" ]; then
        echo -e "Backend API: ${GREEN}Healthy${NC}"
    else
        echo -e "Backend API: ${RED}Unhealthy (HTTP $BACKEND_HEALTH)${NC}"
    fi
    
    # Check frontend
    FRONTEND_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN || echo "000")
    if [ "$FRONTEND_HEALTH" == "200" ]; then
        echo -e "Frontend:    ${GREEN}Healthy${NC}"
    else
        echo -e "Frontend:    ${RED}Unhealthy (HTTP $FRONTEND_HEALTH)${NC}"
    fi
    
    # Check MySQL
    MYSQL_HEALTH=$(docker-compose -f $COMPOSE_FILE exec -T mysql mysqladmin ping 2>/dev/null || echo "failed")
    if [[ "$MYSQL_HEALTH" == *"alive"* ]]; then
        echo -e "MySQL:       ${GREEN}Healthy${NC}"
    else
        echo -e "MySQL:       ${RED}Unhealthy${NC}"
    fi
    
    # Check Redis
    REDIS_HEALTH=$(docker-compose -f $COMPOSE_FILE exec -T redis redis-cli ping 2>/dev/null || echo "failed")
    if [ "$REDIS_HEALTH" == "PONG" ]; then
        echo -e "Redis:       ${GREEN}Healthy${NC}"
    else
        echo -e "Redis:       ${RED}Unhealthy${NC}"
    fi
    
    echo ""
}

# ===========================================
# Main
# ===========================================

# Change to deployment directory
cd "$DEPLOY_SRC" 2>/dev/null || cd "$DEPLOY_DIR"

case "$1" in
    clone)
        clone_repos
        ;;
    init)
        init_deployment
        ;;
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    update)
        update
        ;;
    update-frontend)
        update_frontend
        ;;
    update-backend)
        update_backend
        ;;
    logs)
        logs "$@"
        ;;
    status)
        status
        ;;
    ssl-init)
        ssl_init
        ;;
    ssl-renew)
        ssl_renew
        ;;
    backup)
        backup
        ;;
    health)
        health
        ;;
    *)
        echo "Finareo Deployment Script"
        echo ""
        echo "Usage: $0 {command}"
        echo ""
        echo "Initial Setup Commands:"
        echo "  clone       Clone backend repository from GitHub"
        echo "  init        Build and prepare for first deployment"
        echo ""
        echo "Service Commands:"
        echo "  start            Start all services"
        echo "  stop             Stop all services"
        echo "  restart          Restart all services"
        echo "  update           Pull latest code and redeploy"
        echo "  update-backend   Update backend only"
        echo "  logs [svc]       View logs (optionally for specific service)"
        echo "  status           Show service status"
        echo "  health           Check service health"
        echo ""
        echo "SSL & Backup Commands:"
        echo "  ssl-init    Initialize SSL certificates"
        echo "  ssl-renew   Renew SSL certificates"
        echo "  backup      Create database backup"
        echo ""
        exit 1
        ;;
esac
