#!/bin/bash
# ===========================================
# Finareo VPS Initial Setup Script
# ===========================================
# Run this script on a fresh VPS
# Usage: chmod +x setup-vps.sh && sudo ./setup-vps.sh

set -e

echo "=========================================="
echo "Finareo VPS Setup Script"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo)${NC}"
    exit 1
fi

# ===========================================
# System Updates
# ===========================================
echo -e "${YELLOW}Updating system packages...${NC}"
apt update && apt upgrade -y

# ===========================================
# Install Docker
# ===========================================
echo -e "${YELLOW}Installing Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    
    # Add current user to docker group
    usermod -aG docker $SUDO_USER || true
    
    # Enable and start Docker
    systemctl enable docker
    systemctl start docker
    echo -e "${GREEN}Docker installed successfully${NC}"
else
    echo -e "${GREEN}Docker already installed${NC}"
fi

# ===========================================
# Install Docker Compose
# ===========================================
echo -e "${YELLOW}Installing Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}Docker Compose ${COMPOSE_VERSION} installed${NC}"
else
    echo -e "${GREEN}Docker Compose already installed${NC}"
fi

# ===========================================
# Install additional tools
# ===========================================
echo -e "${YELLOW}Installing additional tools...${NC}"
apt install -y \
    git \
    curl \
    wget \
    htop \
    vim \
    ufw \
    fail2ban \
    certbot

# ===========================================
# Configure Firewall (UFW)
# ===========================================
echo -e "${YELLOW}Configuring firewall...${NC}"
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw --force enable
echo -e "${GREEN}Firewall configured${NC}"

# ===========================================
# Configure Fail2ban
# ===========================================
echo -e "${YELLOW}Configuring Fail2ban...${NC}"
systemctl enable fail2ban
systemctl start fail2ban
echo -e "${GREEN}Fail2ban configured${NC}"

# ===========================================
# Create deployment directory
# ===========================================
echo -e "${YELLOW}Creating deployment directory...${NC}"
mkdir -p /opt/finareo
chown $SUDO_USER:$SUDO_USER /opt/finareo
echo -e "${GREEN}Deployment directory created at /opt/finareo${NC}"

# ===========================================
# Setup swap (for low-memory VPS)
# ===========================================
echo -e "${YELLOW}Setting up swap...${NC}"
if [ ! -f /swapfile ]; then
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo -e "${GREEN}4GB swap created${NC}"
else
    echo -e "${GREEN}Swap already exists${NC}"
fi

# ===========================================
# Configure sysctl for better performance
# ===========================================
echo -e "${YELLOW}Optimizing system settings...${NC}"
cat >> /etc/sysctl.conf << EOF

# Finareo optimizations
vm.swappiness=10
net.core.somaxconn=65535
net.ipv4.tcp_max_tw_buckets=1440000
net.ipv4.ip_local_port_range=1024 65535
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_keepalive_time=300
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_keepalive_intvl=15
EOF
sysctl -p

echo ""
echo "=========================================="
echo -e "${GREEN}VPS Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Clone your deployment repository to /opt/finareo"
echo "2. Copy .env.example to .env and configure it"
echo "3. Run the deployment script: ./deploy.sh"
echo ""
echo "Important: Log out and back in for docker group changes to take effect"
echo ""
