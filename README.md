# 💰 Finareo Deployment

Production deployment configuration for the Finareo personal portfolio management platform.

## Architecture

- **Frontend**: React + Vite on Vercel
- **Backend**: Spring Boot 3.5 API on VPS (Docker)
- **Database**: MySQL 8.0
- **Cache**: Redis 7

## Quick Links

- 📖 **[Full Documentation](./docs/README.md)** - Complete deployment guide

## Live Site

- **Frontend**: https://finareo.vercel.app (or your custom domain)
- **API**: https://api.finareo.com

## Quick Commands (on VPS)

```bash
cd /opt/finareo/deployment

# Status & Health
./scripts/deploy.sh status       # Container status
./scripts/deploy.sh health       # Health check

# Deploy
./scripts/deploy.sh update       # Full backend update
./scripts/deploy.sh update-backend   # Backend only

# Logs
./scripts/deploy.sh logs         # All logs
./scripts/deploy.sh logs backend # Backend only

# Backup
./scripts/backup.sh manual       # Create backup
./scripts/backup.sh list         # List backups
```

## Services

| Service | Tech | Port |
|---------|------|------|
| Nginx | nginx:alpine | 80, 443 |
| Backend | Spring Boot 3.5.7 | 8000 |
| MySQL | MySQL 8.0 | 3306 |
| Redis | Redis 7 | 6379 |

## Setup

1. **VPS Setup**: `sudo ./scripts/setup-vps.sh`
2. **Clone repos**: `./scripts/deploy.sh clone`
3. **Configure**: `cp .env.example .env && nano .env`
4. **Deploy**: `./scripts/deploy.sh start`
5. **SSL**: `./scripts/deploy.sh ssl-init`
- `nginx/**`
- `backend/**`
- `scripts/**`

Manual deploy: **Actions** → **Deploy to Production** → **Run workflow**

---

See [docs/README.md](./docs/README.md) for complete documentation.
