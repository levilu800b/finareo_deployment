#!/bin/bash

# 🚀 LiveLens Local Development Setup Script
# Run this script to set up your local development environment

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

log "🚀 Setting up LiveLens local development environment..."

# Check prerequisites
log "🔍 Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    error "Docker is not installed! Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    error "Docker Compose is not installed! Please install Docker Compose first."
    exit 1
fi

if ! command -v node &> /dev/null; then
    warning "Node.js not found. You can still use Docker, but local development will require Node.js 18+."
fi

if ! command -v yarn &> /dev/null; then
    warning "Yarn not found. Installing via npm..."
    npm install -g yarn || warning "Could not install yarn globally. Use npm instead."
fi

success "Prerequisites check completed!"

# Check if repositories exist
log "📁 Checking repository structure..."

if [ ! -d "../livelens_frontend" ]; then
    error "Frontend repository not found at ../livelens_frontend"
    log "Please clone the frontend repository:"
    log "git clone https://github.com/levilu800b/livelens_frontend.git ../livelens_frontend"
    exit 1
fi

if [ ! -d "../liveLens_backend" ]; then
    error "Backend repository not found at ../liveLens_backend"
    log "Please clone the backend repository:"
    log "git clone https://github.com/levilu800b/liveLens_backend.git ../liveLens_backend"
    exit 1
fi

success "Repository structure verified!"

# Set up frontend dependencies
log "📦 Setting up frontend dependencies..."
cd ../livelens_frontend
if [ -f "package.json" ]; then
    if command -v yarn &> /dev/null; then
        yarn install --frozen-lockfile
    else
        npm ci
    fi
    success "Frontend dependencies installed!"
else
    warning "No package.json found in frontend directory"
fi
cd ../livelens_deployment

# Set up backend dependencies
log "🐍 Setting up backend dependencies..."
cd ../liveLens_backend
if [ -f "requirements.txt" ]; then
    if command -v python3 &> /dev/null; then
        python3 -m venv venv || warning "Could not create virtual environment"
        if [ -f "venv/bin/activate" ]; then
            source venv/bin/activate
            pip install -r requirements.txt
            pip install -r requirements-test.txt || warning "Could not install test dependencies"
            success "Backend dependencies installed!"
        else
            warning "Virtual environment not created. Dependencies not installed."
        fi
    else
        warning "Python 3 not found. Backend dependencies not installed."
    fi
else
    warning "No requirements.txt found in backend directory"
fi
cd ../livelens_deployment

# Create Docker development files if they don't exist
log "🐳 Setting up Docker configuration..."

# Start Docker services
log "🚀 Starting Docker services..."
docker-compose -f docker-compose.local.yml up -d

log "⏳ Waiting for services to be ready..."
sleep 10

# Check if services are running
log "🔍 Checking service status..."
docker-compose -f docker-compose.local.yml ps

# Wait for database to be ready
log "🗄️ Waiting for database to be ready..."
until docker-compose -f docker-compose.local.yml exec -T mysql mysqladmin ping -h localhost -u root -proot_password --silent; do
    log "Waiting for database..."
    sleep 2
done
success "Database is ready!"

# Run initial migrations
log "🔄 Running database migrations..."
docker-compose -f docker-compose.local.yml exec -T backend python manage.py migrate || warning "Migrations failed - you may need to run them manually"

# Create superuser (optional)
log "👤 Creating superuser (optional)..."
echo "Would you like to create a superuser for the admin interface? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    docker-compose -f docker-compose.local.yml exec backend python manage.py createsuperuser
fi

# Display success message
cat << EOF

${GREEN}🎉 LiveLens development environment is ready!${NC}

📋 Service URLs:
   Frontend: ${BLUE}http://localhost:3000${NC}
   Backend:  ${BLUE}http://localhost:8000${NC}
   Admin:    ${BLUE}http://localhost:8000/admin${NC}

🛠️ Useful commands:
   View logs:        ${YELLOW}docker-compose -f docker-compose.local.yml logs -f${NC}
   Stop services:    ${YELLOW}docker-compose -f docker-compose.local.yml down${NC}
   Restart service:  ${YELLOW}docker-compose -f docker-compose.local.yml restart backend${NC}
   Run migrations:   ${YELLOW}docker-compose -f docker-compose.local.yml exec backend python manage.py migrate${NC}

📚 Documentation:
   Full commands:    ${YELLOW}cat DEPLOYMENT_COMMANDS.md${NC}
   Platform status:  ${YELLOW}cat PLATFORM_STATUS.md${NC}

🚀 Start developing! Make changes to your code and see them reflected automatically.

EOF

success "Setup completed successfully!"
