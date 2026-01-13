# 🚀 Finareo Deployment Guide

Complete guide for deploying and managing the Finareo personal portfolio management platform.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Repository Structure](#repository-structure)
- [Initial VPS Setup](#initial-vps-setup)
- [Cloudflare Tunnel Setup](#cloudflare-tunnel-setup)
- [Netlify Frontend Setup](#netlify-frontend-setup)
- [GitHub Actions CI/CD](#github-actions-cicd)
- [Deployment Commands](#deployment-commands)
- [Database Backups](#database-backups)
- [Troubleshooting](#troubleshooting)

---

## 🏗️ Architecture Overview

```
┌─────────────────┐     HTTPS      ┌──────────────────────┐
│                 │◄──────────────►│   Cloudflare Tunnel  │
│   Netlify       │                │  (trycloudflare.com) │
│   Frontend      │                └──────────┬───────────┘
│                 │                           │
└─────────────────┘                           │ localhost:8000
                                              ▼
                                   ┌──────────────────────┐
                                   │        VPS           │
                                   │  ┌────────────────┐  │
                                   │  │ Spring Boot    │  │
                                   │  │ Backend :8000  │  │
                                   │  └───────┬────────┘  │
                                   │          │           │
                                   │  ┌───────┴────────┐  │
                                   │  │ MySQL :3307    │  │
                                   │  │ Redis :6379    │  │
                                   │  └────────────────┘  │
                                   └──────────────────────┘
```

| Component | Technology | Location | Port |
|-----------|------------|----------|------|
| **Frontend** | React 19, Vite, TailwindCSS 4 | Netlify | - |
| **HTTPS Tunnel** | Cloudflare Tunnel | VPS | - |
| **Backend** | Spring Boot 3.5.7, Java 25 | VPS Docker | 8000 |
| **Database** | MySQL 8.0 | VPS Docker | 3307 |
| **Cache** | Redis 7 Alpine | VPS Docker | 6379 (internal) |
| **Reverse Proxy** | Nginx Alpine | VPS Docker | 8081/8444 |

**Note:** Finareo runs alongside StrymHub on the same VPS. To avoid conflicts:
- Finareo uses port **8000** (StrymHub uses 8080)
- Finareo MySQL uses port **3307** (StrymHub uses 3306)
- Docker project name is `finareo` (use `-p finareo` flag)

---

## 📁 Repository Structure

```
finareo_deployment/
├── .env.example            # Template for .env
├── docker-compose.yml      # Main Docker configuration
├── docker-compose.prod.yml # Production overrides
├── .github/
│   └── workflows/
│       └── deploy.yml      # GitHub Actions CI/CD
├── backend/
│   └── Dockerfile          # Backend container build
├── nginx/
│   ├── nginx.conf          # Main Nginx config
│   └── conf.d/
│       └── finareo.conf    # API configuration
├── mysql/
│   └── init/               # Database initialization scripts
├── scripts/
│   ├── deploy.sh           # Main deployment script
│   ├── backup.sh           # Database backup script
│   └── setup-vps.sh        # Initial VPS setup
└── docs/
    └── README.md           # This file
```

**Related Repositories:**
- `Finareo_UI` - React 19 + Vite frontend (deployed to Netlify)
- `Finareo_backend` - Spring Boot API

---

## 🖥️ Initial VPS Setup

### Prerequisites
- Ubuntu VPS with Docker installed
- SSH access as root
- GitHub Personal Access Token (for private repos)

### Step 1: Create Project Directory

```bash
ssh root@your-vps-ip
mkdir -p /opt/finareo
cd /opt/finareo
```

### Step 2: Clone Repositories

```bash
# Clone deployment config
git clone https://YOUR_GITHUB_TOKEN@github.com/levilu800b/finareo_deployment.git deployment

# Clone backend source
git clone https://YOUR_GITHUB_TOKEN@github.com/levilu800b/Finareo_backend.git backend-src
```

### Step 3: Configure Environment

```bash
cd /opt/finareo/deployment
cp .env.example .env
nano .env
```

**Required .env variables:**
```env
# Database
MYSQL_ROOT_PASSWORD=your_secure_password
MYSQL_DATABASE=finareo
MYSQL_USER=finareo
MYSQL_PASSWORD=your_secure_password

# IMPORTANT: This creates tables on first run
DDL_AUTO=update

# Security
JWT_SECRET=your_64_character_secret_key
CORS_ALLOWED_ORIGINS=https://your-app.netlify.app

# Email (for verification/password reset)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USERNAME=your_email@gmail.com
EMAIL_PASSWORD=your_app_password
```

### Step 4: Copy Backend Source & Build

```bash
# Copy source to deployment folder
cp -r /opt/finareo/backend-src/src /opt/finareo/deployment/backend/
cp /opt/finareo/backend-src/pom.xml /opt/finareo/deployment/backend/

# Build and start (IMPORTANT: use -p finareo to avoid conflicts)
cd /opt/finareo/deployment
docker-compose -p finareo -f docker-compose.yml -f docker-compose.prod.yml build --no-cache backend
docker-compose -p finareo -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### Step 5: Verify Deployment

```bash
# Check containers are running
docker ps | grep finareo

# Check backend logs
docker logs finareo-backend --tail 50

# Test API
curl http://localhost:8000/api/v1/
```

---

## 🌐 Cloudflare Tunnel Setup

Cloudflare Tunnel provides **free HTTPS** without needing a domain name. This is required because Netlify serves over HTTPS, and browsers block mixed HTTP/HTTPS content.

### Step 1: Install Cloudflared

```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared
```

### Step 2: Start Tunnel (Quick Test)

```bash
cloudflared tunnel --url http://localhost:8000
```

You'll see output like:
```
Your quick Tunnel has been created! Visit it at:
https://random-words-here.trycloudflare.com
```

### Step 3: Run Tunnel in Background

```bash
nohup cloudflared tunnel --url http://localhost:8000 > /var/log/cloudflared-finareo.log 2>&1 &
```

### Step 4: Get the Tunnel URL

```bash
cat /var/log/cloudflared-finareo.log | grep trycloudflare
```

**⚠️ Important:** The URL changes each time the tunnel restarts. After a VPS reboot:
1. Re-run the tunnel command
2. Get the new URL
3. Update Netlify environment variable

### Managing the Tunnel

```bash
# Check if tunnel is running
ps aux | grep cloudflared

# View tunnel logs
tail -f /var/log/cloudflared-finareo.log

# Stop tunnel
pkill cloudflared

# Restart tunnel
nohup cloudflared tunnel --url http://localhost:8000 > /var/log/cloudflared-finareo.log 2>&1 &
```

### Multiple Projects

Each project can have its own tunnel on different ports:
```bash
# Finareo (port 8000)
nohup cloudflared tunnel --url http://localhost:8000 > /var/log/cloudflared-finareo.log 2>&1 &

# StrymHub (port 8080) - if needed
nohup cloudflared tunnel --url http://localhost:8080 > /var/log/cloudflared-strymhub.log 2>&1 &
```

---

## 🌍 Netlify Frontend Setup

### Step 1: Connect Repository

1. Go to [Netlify Dashboard](https://app.netlify.com)
2. Click **"Add new site"** → **"Import an existing project"**
3. Connect to GitHub and select `Finareo_UI` repository
4. Configure build settings:
   - **Build command:** `yarn run build`
   - **Publish directory:** `dist`

### Step 2: Configure Environment Variables

Go to **Site configuration** → **Environment variables** and add:

| Key | Value |
|-----|-------|
| `VITE_API_BASE_URL` | `https://your-tunnel-url.trycloudflare.com/api/v1` |

**⚠️ Remember:** Update this whenever the Cloudflare Tunnel URL changes.

### Step 3: Deploy

Netlify automatically deploys when you push to the `master` branch.

**Manual Redeploy:**
1. Go to **Deploys** tab
2. Click **"Trigger deploy"** → **"Deploy site"**

### Troubleshooting Build Errors

If TypeScript errors occur, the build is configured to skip type checking:
```json
{
  "scripts": {
    "build": "vite build"
  }
}
```

For local type checking, use: `npm run build:check`

---

## 🔄 GitHub Actions CI/CD

The deployment workflow automatically:
1. Creates a database backup before deployment
2. Pulls latest code from both repos
3. Rebuilds and restarts Docker containers
4. Creates a post-deployment backup
5. Cleans up old backups (>7 days)

### Required GitHub Secrets

Go to Repository **Settings** → **Secrets and variables** → **Actions**:

| Secret | Value |
|--------|-------|
| `VPS_HOST` | Your VPS IP address |
| `VPS_USERNAME` | `root` |
| `VPS_PORT` | `22` |
| `VPS_PRIVATE_KEY` | Contents of your SSH private key |
| `MYSQL_ROOT_PASSWORD` | Your MySQL root password |

### Trigger Deployment

Deployments are triggered when you push changes to:
- `docker-compose*.yml`
- `nginx/**`
- `backend/**`
- `scripts/**`
- `.github/workflows/**`

Or manually via GitHub Actions → **"Run workflow"**

---

## 🛠️ Deployment Commands

All commands run from `/opt/finareo/deployment`:

### Docker Commands (Use -p finareo flag!)

```bash
# Start all services
docker-compose -p finareo -f docker-compose.yml -f docker-compose.prod.yml up -d

# Stop all services
docker-compose -p finareo -f docker-compose.yml -f docker-compose.prod.yml down

# Rebuild backend only
docker-compose -p finareo -f docker-compose.yml -f docker-compose.prod.yml build --no-cache backend
docker-compose -p finareo -f docker-compose.yml -f docker-compose.prod.yml up -d backend

# View logs
docker logs finareo-backend --tail 100 -f
docker logs finareo-mysql --tail 100 -f

# Check container status
docker ps | grep finareo
```

**⚠️ CRITICAL:** Always use `-p finareo` to keep containers isolated from other projects (like StrymHub).

### Quick Update Workflow

```bash
cd /opt/finareo

# Pull latest backend code
cd backend-src && git pull origin master && cd ..

# Copy to deployment
cd deployment
cp -r ../backend-src/src backend/
cp ../backend-src/pom.xml backend/

# Rebuild and restart
docker-compose -p finareo -f docker-compose.yml -f docker-compose.prod.yml build --no-cache backend
docker-compose -p finareo -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## 💾 Database Backups

### Manual Backup

```bash
# Create backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
docker exec finareo-mysql mysqldump -u root -p'YOUR_PASSWORD' finareo > /opt/finareo/backups/finareo_${TIMESTAMP}.sql

# Compress it
gzip /opt/finareo/backups/finareo_${TIMESTAMP}.sql
```

### Restore from Backup

```bash
# Decompress if needed
gunzip /opt/finareo/backups/finareo_backup.sql.gz

# Restore
docker exec -i finareo-mysql mysql -u root -p'YOUR_PASSWORD' finareo < /opt/finareo/backups/finareo_backup.sql
```

### Backup Location

```
/opt/finareo/backups/
├── finareo_pre_deploy_YYYYMMDD_HHMMSS.sql    # Before deployments
├── finareo_post_deploy_YYYYMMDD_HHMMSS.sql.gz # After deployments
└── finareo_manual_YYYYMMDD_HHMMSS.sql.gz      # Manual backups
```

### Automated Backups

GitHub Actions creates backups automatically:
- **Pre-deployment:** Before any changes
- **Post-deployment:** After successful deployment
- **Cleanup:** Removes backups older than 7 days

---

## 🔧 Troubleshooting

### Backend Won't Start

```bash
# Check logs
docker logs finareo-backend --tail 100

# Common issues:
# - Missing environment variables
# - Database connection failed
# - Port already in use
```

### Database Connection Issues

```bash
# Check MySQL is running
docker ps | grep finareo-mysql

# Connect to MySQL directly
docker exec -it finareo-mysql mysql -u root -p'YOUR_PASSWORD' finareo

# Check tables exist
SHOW TABLES;
```

### "Table doesn't exist" Error

Add to `.env`:
```env
DDL_AUTO=update
```
Then restart backend. Change to `validate` after tables are created.

### CORS Issues

1. Check `CORS_ALLOWED_ORIGINS` in `.env` includes your Netlify domain
2. Restart backend after changing `.env`

### Cloudflare Tunnel Not Working

```bash
# Check if running
ps aux | grep cloudflared

# Check logs
cat /var/log/cloudflared-finareo.log

# Restart tunnel
pkill cloudflared
nohup cloudflared tunnel --url http://localhost:8000 > /var/log/cloudflared-finareo.log 2>&1 &

# Get new URL
cat /var/log/cloudflared-finareo.log | grep trycloudflare
```

### Port Conflicts with StrymHub

| Service | Finareo | StrymHub |
|---------|---------|----------|
| Backend | 8000 | 8080 |
| MySQL | 3307 | 3306 |
| Nginx HTTP | 8081 | 80 |
| Nginx HTTPS | 8444 | 443 |

---

## 🔒 Security Checklist

- [ ] Strong passwords in `.env`
- [ ] `DDL_AUTO=validate` after initial deploy (prevents accidental schema changes)
- [ ] Firewall enabled (`ufw status`)
- [ ] JWT_SECRET is 64+ characters
- [ ] CORS only allows your Netlify domain

---

## 🆘 Quick Health Check

```bash
# SSH to VPS
ssh root@your-vps-ip

# Check all Finareo containers
docker ps | grep finareo

# Check API is responding
curl http://localhost:8000/api/v1/

# Check Cloudflare tunnel
cat /var/log/cloudflared-finareo.log | grep trycloudflare
```

---

## 📝 Important Notes

### After VPS Reboot

1. Docker containers should auto-start
2. Cloudflare tunnel needs manual restart:
   ```bash
   nohup cloudflared tunnel --url http://localhost:8000 > /var/log/cloudflared-finareo.log 2>&1 &
   ```
3. Update Netlify environment variable with new tunnel URL

### Running Multiple Projects

This VPS hosts both Finareo and StrymHub. Key isolation rules:

1. **Always use `-p finareo`** for docker-compose commands
2. **Never run** `docker-compose` without the `-p` flag
3. StrymHub uses `deployment_mysql_data` volume
4. Finareo uses `finareo_mysql_data` volume

### Current URLs

| Service | URL |
|---------|-----|
| Frontend | `https://your-app.netlify.app` |
| API (via tunnel) | `https://xxx.trycloudflare.com/api/v1` |
| API (direct) | `http://VPS_IP:8000/api/v1` |

---

*Last updated: January 2026*
