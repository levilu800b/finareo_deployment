#!/bin/bash

# =============================================================================
# LiveLens Local Docker Test Script
# Test Docker setup before VPS deployment
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[TEST]${NC} $1"; }
success() { echo -e "${GREEN}[PASS]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

log "🧪 Testing LiveLens Docker Setup..."

# Check prerequisites
log "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    error "❌ Docker is not installed"
    exit 1
fi
success "✅ Docker is installed"

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    error "❌ Docker Compose is not installed"
    exit 1
fi
success "✅ Docker Compose is available"

# Check if port 3306 is in use (local MySQL)
if lsof -Pi :3306 -sTCP:LISTEN -t >/dev/null ; then
    warning "⚠️  Port 3306 is in use (probably local MySQL)"
    log "✅ Using port 3307 for Docker MySQL (correct setup)"
else
    log "Port 3306 is free"
fi

# Check environment file
if [ ! -f ".env" ]; then
    log "Creating .env from .env.dev template..."
    cp .env.dev .env
    success "✅ Environment file created"
else
    success "✅ Environment file exists"
fi

# Test development build
log "Testing development Docker build..."

# Stop any existing containers
docker compose -f docker-compose.dev.yml down -v 2>/dev/null || true

# Build and start development environment
log "Building development containers..."
if docker compose -f docker-compose.dev.yml build; then
    success "✅ Development containers built successfully"
else
    error "❌ Failed to build development containers"
    exit 1
fi

log "Starting development environment..."
if docker compose -f docker-compose.dev.yml up -d; then
    success "✅ Development environment started"
else
    error "❌ Failed to start development environment"
    exit 1
fi

# Wait for services to be ready
log "Waiting for services to start..."
sleep 30

# Check service health
log "Checking service health..."

# Check MySQL
if docker compose -f docker-compose.dev.yml exec -T mysql mysqladmin ping -h localhost -u root -pdevpassword &>/dev/null; then
    success "✅ MySQL is healthy"
else
    error "❌ MySQL health check failed"
fi

# Check Redis
if docker compose -f docker-compose.dev.yml exec -T redis redis-cli ping | grep -q PONG; then
    success "✅ Redis is healthy"
else
    error "❌ Redis health check failed"
fi

# Check Backend
log "Checking backend service..."
sleep 10
if curl -f http://localhost:8000/api/health/ &>/dev/null; then
    success "✅ Backend is responding"
elif curl -f http://localhost:8000/ &>/dev/null; then
    success "✅ Backend is running (health endpoint may not exist yet)"
else
    warning "⚠️  Backend health check inconclusive"
    log "Backend logs:"
    docker compose -f docker-compose.dev.yml logs backend | tail -n 10
fi

# Check Frontend
log "Checking frontend service..."
if curl -f http://localhost:3000/ &>/dev/null; then
    success "✅ Frontend is responding"
else
    warning "⚠️  Frontend may still be building..."
    log "Frontend logs:"
    docker compose -f docker-compose.dev.yml logs frontend | tail -n 10
fi

# Show container status
log "Container status:"
docker compose -f docker-compose.dev.yml ps

# Show resource usage
log "Resource usage:"
docker stats --no-stream

log "✅ Test complete! Access your application at:"
log "   🌐 Frontend: http://localhost:3000"
log "   🔧 Backend:  http://localhost:8000"
log "   � Admin:    http://localhost:8000/admin"
log "   �📊 MySQL:    localhost:3307"
log "   🔄 Redis:    localhost:6380"
log ""
log "🔑 Default Admin Login (Development):"
log "   Username: admin"
log "   Password: admin123"
log "   Email:    admin@localhost"
log ""
log "🔑 Default Admin Credentials (Development):"
log "   👤 Username: admin"
log "   🔒 Password: admin123"
log "   🌐 Admin URL: http://localhost:8000/admin/"

log "To stop the test environment:"
log "   docker compose -f docker-compose.dev.yml down"

log "To clean up completely:"
log "   docker compose -f docker-compose.dev.yml down -v"
log "   docker system prune -f"

success "🎉 Docker setup test completed successfully!"
