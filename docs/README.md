# 🚀 Finareo Deployment Guide

Complete guide for deploying and managing the Finareo personal portfolio management platform.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Repository Structure](#repository-structure)
- [Initial VPS Setup](#initial-vps-setup)
- [Vercel Frontend Setup](#vercel-frontend-setup)
- [Deployment Commands](#deployment-commands)
- [Database Backups](#database-backups)
- [Troubleshooting](#troubleshooting)

---

## 🏗️ Architecture Overview

| Component | Technology | Location | Port |
|-----------|------------|----------|------|
| **Frontend** | React 19, Vite | Vercel | - |
| **Nginx** | nginx:alpine | VPS | 80, 443 |
| **Backend** | Spring Boot 3.5.7, Java 25 | VPS | 8000 |
| **MySQL** | MySQL 8.0 | VPS | 3306 |
| **Redis** | Redis 7 Alpine | VPS | 6379 |

---

## 📁 Repository Structure

```
finareo_deployment/
├── .env.example            # Template for .env
├── docker-compose.yml      # Main Docker configuration
├── docker-compose.prod.yml # Production overrides
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
- `Finareo_frontend` - React 19 + Vite frontend (deployed to Vercel)
- `Finareo_backend` - Spring Boot API

---

## 🖥️ Initial VPS Setup

### Prerequisites
- Ubuntu VPS (22.04 LTS recommended)
- Domain pointing to VPS IP (A record for api.finareo.com)
- SSH access as root

### Step 1: Run Setup Script

```bash
ssh root@your-vps-ip
apt update && apt install -y git
git clone https://github.com/levilu800b/finareo_deployment.git /opt/finareo/deployment
cd /opt/finareo/deployment
chmod +x scripts/*.sh
./scripts/setup-vps.sh
```

### Step 2: Clone Backend Repository

```bash
./scripts/deploy.sh clone
```

### Step 3: Configure Environment

```bash
cp .env.example .env
nano .env  # Fill in all values
```

**Required .env variables:**
- `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD` - Database credentials
- `JWT_SECRET` - 64+ character secret key
- `CORS_ALLOWED_ORIGINS` - Your Vercel domain
- `EMAIL_*` - SMTP configuration

### Step 4: Initialize & Deploy

```bash
./scripts/deploy.sh init      # Build everything
./scripts/deploy.sh ssl-init  # Get SSL certificates
./scripts/deploy.sh start     # Start services
```

---

## 🌐 Vercel Frontend Setup

### Step 1: Connect Repository

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Click "New Project"
3. Import `Finareo_frontend` repository
4. Select "Vite" as framework

### Step 2: Configure Environment Variables

In Vercel project settings → Environment Variables:

| Name | Value |
|------|-------|
| `VITE_API_BASE_URL` | `https://api.finareo.com/api/v1` |

### Step 3: Deploy

Vercel automatically deploys on push to main/master branch.

---

## 🛠️ Deployment Commands

All commands run from `/opt/finareo/deployment`:

### Service Management

| Command | Description |
|---------|-------------|
| `./scripts/deploy.sh status` | Show all container statuses |
| `./scripts/deploy.sh start` | Start all services |
| `./scripts/deploy.sh stop` | Stop all services |
| `./scripts/deploy.sh restart` | Restart all services |

### Deployments

| Command | Description |
|---------|-------------|
| `./scripts/deploy.sh update` | Pull repos & redeploy |
| `./scripts/deploy.sh update-backend` | Update backend only |

### Logs

| Command | Description |
|---------|-------------|
| `./scripts/deploy.sh logs` | Follow all logs |
| `./scripts/deploy.sh logs backend` | Backend logs only |

### SSL Certificates

| Command | Description |
|---------|-------------|
| `./scripts/deploy.sh ssl-init` | Initial SSL setup |
| `./scripts/deploy.sh ssl-renew` | Manual renewal |

---

## 💾 Database Backups

### Manual Backup

```bash
./scripts/backup.sh manual    # Create backup
./scripts/backup.sh list      # List backups
```

### Backup Location

```
/opt/finareo/backups/
├── daily/
├── weekly/
└── manual/
```

---

## 🔧 Troubleshooting

### Backend Won't Start

```bash
docker logs finareo-backend --tail 100
```

### Database Access

```bash
source .env
docker exec -it finareo-mysql mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"
```

### CORS Issues

Ensure `CORS_ALLOWED_ORIGINS` in `.env` includes your Vercel domain.

---

## 🔒 Security Checklist

- [ ] Strong passwords in `.env`
- [ ] `DDL_AUTO=validate` after initial deploy
- [ ] Firewall enabled (`ufw status`)
- [ ] SSL certificate active

---

## 🆘 Quick Health Check

```bash
cd /opt/finareo/deployment
./scripts/deploy.sh status
docker ps
```

### URLs

- **Frontend**: https://finareo.vercel.app
- **API Health**: https://api.finareo.com/health

---

*Last updated: January 2026*
