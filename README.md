# LiveLens Platform

A modern live video streaming and social media platform built with React frontend, Django REST API backend, and Docker containerization.

## 🏗️ Architecture

- **Frontend**: React 18 + TypeScript + Vite + Tailwind CSS
- **Backend**: Django 5.1 + Django REST Framework + Python 3.11
- **Database**: MySQL 8.0
- **Cache**: Redis 7
- **Reverse Proxy**: Nginx with SSL (Let's Encrypt)
- **Containerization**: Docker + Docker Compose

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- Git
- Node.js 18+ (for local development)
- Yarn (for frontend package management)
- Python 3.11+ (for local development)

### Local Development Testing

1. **Clone the repositories**:
   ```bash
   git clone https://github.com/levilu800b/livelens_deployment.git
   git clone https://github.com/levilu800b/LiveLens_UI.git
   git clone https://github.com/levilu800b/LiveLens_Backend.git
   ```

2. **Test the Docker setup**:
   ```bash
   cd livelens_deployment
   chmod +x test-docker-setup.sh
   ./test-docker-setup.sh
   ```

3. **Manual development startup**:
   ```bash
   # Start development environment
   docker-compose -f docker-compose.dev.yml up -d
   
   # Check status
   docker-compose -f docker-compose.dev.yml ps
   
   # View logs
   docker-compose -f docker-compose.dev.yml logs -f
   
   # Stop environment
   docker-compose -f docker-compose.dev.yml down
   ```

### Local Development (Non-Docker)

1. **Backend Setup**:
   ```bash
   cd LiveLens_Backend
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   python manage.py migrate
   python manage.py createsuperuser
   python manage.py runserver
   ```

2. **Frontend Setup**:
   ```bash
   cd LiveLens_UI
   yarn install
   yarn dev
   ```

## 🌐 Production Deployment

### Environment Setup

1. **Environment Variables**:
   ```bash
   # Copy and configure production environment
   cp .env.example .env.production
   # Edit .env.production with your production values
   ```

2. **Deploy to Production**:
   ```bash
   # Pull latest changes
   git pull origin master
   cd LiveLens_Backend && git pull origin master
   cd ../LiveLens_UI && git pull origin master
   cd ../livelens_deployment
   
   # Build and deploy
   docker-compose -f docker-compose.hostinger.yml --env-file .env.production up -d --build
   ```

3. **Production Commands**:
   ```bash
   # Check status
   docker-compose -f docker-compose.hostinger.yml ps
   
   # View logs
   docker-compose -f docker-compose.hostinger.yml logs -f [service_name]
   
   # Restart specific service
   docker-compose -f docker-compose.hostinger.yml restart [service_name]
   
   # Stop all services
   docker-compose -f docker-compose.hostinger.yml down
   
   # Update and redeploy
   docker-compose -f docker-compose.hostinger.yml pull
   docker-compose -f docker-compose.hostinger.yml up -d --build
   ```

### GitHub Actions Deployment

The platform includes automated deployment via GitHub Actions. When you push to the `master` branch:

1. **Automatic Deployment** triggers on push to master
2. **Success Indicator**: ✅ Green check = Production has latest changes
3. **Failure Handling**: ❌ Red X = Deployment failed, check logs

**Manual Trigger**:
```bash
# To force a deployment
git commit --allow-empty -m "Trigger deployment"
git push origin master
```

## 📡 API Documentation

### Base URLs
- **Production**: `https://livelens.space/api/`
- **Development**: `http://localhost:8000/api/`

### API Endpoints

#### Health & System
- `GET /api/health/` - Health check
- `GET /api/docs/` - Swagger API documentation
- `GET /api/redoc/` - ReDoc API documentation
- `GET /api/schema/` - OpenAPI schema

#### Authentication
- `POST /api/auth/login/` - User login
- `POST /api/auth/logout/` - User logout
- `POST /api/auth/register/` - User registration
- `POST /api/auth/refresh/` - Refresh JWT token

#### User Management
- `GET /api/user/profile/` - Get user profile
- `PUT /api/user/profile/` - Update user profile
- `POST /api/user/change-password/` - Change password

#### Content Management
- `GET /api/stories/` - List stories
- `POST /api/stories/` - Create story
- `GET /api/media/` - List media content
- `POST /api/media/` - Upload media
- `GET /api/podcasts/` - List podcasts
- `GET /api/animations/` - List animations
- `GET /api/sneak-peeks/` - List sneak peeks

#### Live Video
- `GET /api/live-video/` - List live streams
- `POST /api/live-video/` - Start live stream
- `PUT /api/live-video/{id}/` - Update live stream

#### Social Features
- `GET /api/comments/` - List comments
- `POST /api/comments/` - Create comment
- `GET /api/email-notifications/` - List notifications

#### Admin Dashboard
- `GET /api/admin-dashboard/stats/` - Platform statistics
- `GET /api/admin-dashboard/users/` - User management

### Authentication

The API uses JWT (JSON Web Token) authentication:

```bash
# Login and get token
curl -X POST https://livelens.space/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username": "your_username", "password": "your_password"}'

# Use token in subsequent requests
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  https://livelens.space/api/user/profile/
```

## 🔧 Development Commands

### Frontend (React/Vite)
```bash
yarn dev             # Start development server
yarn build           # Production build
yarn preview         # Preview production build
yarn lint            # Run ESLint
yarn lint:fix        # Fix ESLint issues
yarn format          # Format code with Prettier
yarn type-check      # TypeScript type checking
```

### Backend (Django)
```bash
python manage.py runserver          # Start development server
python manage.py migrate            # Run database migrations
python manage.py makemigrations     # Create new migrations
python manage.py createsuperuser    # Create admin user
python manage.py collectstatic      # Collect static files
python manage.py shell              # Django shell
python manage.py test               # Run tests
```

### Docker Commands
```bash
# Development
docker-compose -f docker-compose.dev.yml up -d
docker-compose -f docker-compose.dev.yml logs -f
docker-compose -f docker-compose.dev.yml down

# Production
docker-compose -f docker-compose.hostinger.yml up -d
docker-compose -f docker-compose.hostinger.yml ps
docker-compose -f docker-compose.hostinger.yml restart frontend

# Cleanup
docker system prune -a -f
docker volume prune -f
```

## 🌍 Access URLs

### Production
- **Website**: https://livelens.space
- **API**: https://livelens.space/api/
- **Admin**: https://livelens.space/admin/
- **API Docs**: https://livelens.space/api/docs/

### Development
- **Website**: http://localhost:3000
- **API**: http://localhost:8000/api/
- **Admin**: http://localhost:8000/admin/
- **MySQL**: localhost:3307
- **Redis**: localhost:6380

## 🔒 Security Features

- SSL/TLS encryption (Let's Encrypt)
- JWT authentication
- CORS protection
- Rate limiting
- Input validation
- SQL injection protection
- XSS protection

## 📊 Monitoring & Logs

### Data Persistence

**✅ Your database data PERSISTS across deployments!**

When you push changes to GitHub and deploy:
- ✅ **Database records remain intact** (users, posts, media, etc.)
- ✅ **Uploaded files are preserved**
- ✅ **Only application code updates**

**Safe Operations** (Data is kept):
```bash
git push origin master              # GitHub Actions deployment
docker-compose up -d --build        # Rebuild containers
docker-compose restart              # Restart services
docker-compose down && up -d        # Recreate containers
```

**⚠️ DANGEROUS Operations** (Would delete data):
```bash
docker-compose down -v              # -v removes volumes
docker volume rm mysql_data         # Deletes database
docker system prune --volumes       # Removes all volumes
```

### Database Backup

Create regular backups with the included script:
```bash
chmod +x scripts/backup-database.sh
./scripts/backup-database.sh
```

### Disk Space Management

**Automated maintenance script:**
```bash
# On your VPS via SSH
chmod +x scripts/vps-maintenance.sh
./scripts/vps-maintenance.sh
```

**Manual cleanup (SAFE - doesn't affect database):**
```bash
# On your VPS via SSH
docker system prune -a -f           # Remove unused images and cache
docker builder prune -a -f          # Remove build cache
```

### Maintenance Schedule

**🕐 Best Times to Run Cleanup:**

**Option 1: Monthly Automated (Recommended)**
```bash
# Set up cron job on VPS - 1st of month at 2 AM
ssh root@your-vps
crontab -e
# Add this line:
0 2 1 * * /opt/livelens/livelens_deployment/scripts/vps-maintenance.sh >> /var/log/vps-maintenance.log 2>&1
```

**Option 2: Manual When Needed**
```bash
# Check disk usage first
ssh root@your-vps "df -h /"
# If disk usage > 75%, run maintenance
```

**🚨 Run Maintenance When:**
- Disk usage exceeds 75-80%
- After multiple deployments in a week  
- Before major updates/releases
- After failed deployments

**🔍 Quick Disk Check:**
```bash
# Check current disk and Docker usage
ssh root@your-vps "df -h / && echo '---' && docker system df"
```

**⚠️ This command is SAFE because it only removes:**
- Unused Docker images
- Stopped containers  
- Unused networks
- Build cache

**✅ It NEVER affects:**
- Running containers
- Database volumes
- Database data
- Active services

**When to use:** When disk space gets low (recommended monthly or when deploying frequently)

### View Logs
```bash
# All services
docker-compose -f docker-compose.hostinger.yml logs -f

# Specific service
docker logs livelens_frontend
docker logs livelens_backend
docker logs livelens_nginx
```

### Health Checks
```bash
# API health
curl https://livelens.space/api/health/

# Container health
docker-compose -f docker-compose.hostinger.yml ps
```

## � Quick Reference Commands

### Regular Maintenance
```bash
# Check disk space
ssh root@your-vps "df -h /"

# Check Docker usage  
ssh root@your-vps "docker system df"

# Run maintenance (when disk > 75%)
ssh root@your-vps "cd /opt/livelens/livelens_deployment && ./scripts/vps-maintenance.sh"

# Check container status
ssh root@your-vps "docker-compose -f /opt/livelens/livelens_deployment/docker-compose.hostinger.yml ps"
```

### Development Workflow
```bash
# Test locally first
cd livelens_deployment && ./test-docker-setup.sh

# Deploy to production
git push origin master  # GitHub Actions handles deployment

# Verify deployment
curl -s -o /dev/null -w '%{http_code}' https://livelens.space
```

## �🚨 Troubleshooting

### Common Issues

1. **Port conflicts**: Ensure ports 3000, 8000, 3306, 6379 are available
2. **Docker issues**: Run `docker system prune -a -f` to clean up
3. **Build failures**: Check logs with `docker-compose logs [service]`
4. **Database issues**: Verify MySQL container is healthy
5. **SSL issues**: Check certificate renewal status
6. **Disk space full**: Clean up with `docker system prune -a -f` (safe, preserves database)

### Reset Development Environment
```bash
docker-compose -f docker-compose.dev.yml down -v
docker system prune -a -f
./test-docker-setup.sh
```

## 📝 Development Workflow

1. **Make changes locally** in LiveLens_UI or LiveLens_Backend
2. **Test locally** using `./test-docker-setup.sh` or `docker-compose.dev.yml`
3. **Commit and push** to respective repositories
4. **GitHub Actions** automatically deploys to production
5. **Verify deployment** by checking the green ✅ in GitHub and visiting the site

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test locally with Docker
4. Submit a pull request
5. Ensure all tests pass

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For issues and support:
1. Check the troubleshooting section
2. Review application logs
3. Verify all services are running
4. Check API documentation for correct endpoints
