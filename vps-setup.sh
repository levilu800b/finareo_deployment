#!/bin/bash

# =============================================================================
# Manual LiveLens VPS Setup (Copy-Paste Method)
# For when you can't download from GitHub directly
# =============================================================================

set -e

echo "🚀 Setting up LiveLens on Hostinger VPS..."

# Update system
echo "📦 Updating system..."
apt update && apt upgrade -y

# Install required packages
echo "📋 Installing required packages..."
apt install -y \
    curl \
    wget \
    git \
    docker.io \
    docker-compose-plugin \
    nginx \
    certbot \
    python3-certbot-nginx \
    ufw \
    fail2ban

# Enable Docker
systemctl enable docker
systemctl start docker

# Configure firewall
echo "🔒 Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Create deployment directory
mkdir -p /opt/livelens
cd /opt/livelens

# Generate SSH key for GitHub access
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "🔑 Generating SSH key for GitHub access..."
    ssh-keygen -t rsa -b 4096 -C "deploy@livelens.space" -f ~/.ssh/id_rsa -N ""
    
    echo ""
    echo "=============================================="
    echo "🔑 SSH PUBLIC KEY FOR GITHUB DEPLOY KEYS"
    echo "=============================================="
    echo "Copy this public key and add it as a deploy key to ALL THREE repositories:"
    echo ""
    cat ~/.ssh/id_rsa.pub
    echo ""
    echo "📋 To add deploy keys:"
    echo "1. Go to each GitHub repository:"
    echo "   - https://github.com/YOUR-USERNAME/LiveLens_UI"
    echo "   - https://github.com/YOUR-USERNAME/LiveLens_Backend"
    echo "   - https://github.com/YOUR-USERNAME/livelens_deployment"
    echo ""
    echo "2. For each repository:"
    echo "   - Go to Settings > Deploy keys"
    echo "   - Click 'Add deploy key'"
    echo "   - Title: 'Production VPS Deploy Key'"
    echo "   - Paste the public key above"
    echo "   - ✅ Check 'Allow write access'"
    echo "   - Click 'Add key'"
    echo ""
    echo "=============================================="
    echo ""
    echo "⚠️  After adding deploy keys to all repositories, run:"
    echo "   ./continue-deployment.sh"
fi

# Add GitHub to known hosts
ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>/dev/null || true

# Create continuation script
cat > continue-deployment.sh << 'EOF'
#!/bin/bash

set -e

# Configuration
DOMAIN="livelens.space"

# Prompt for GitHub username
read -p "Enter your GitHub username: " GITHUB_USER
FRONTEND_REPO="git@github.com:${GITHUB_USER}/LiveLens_UI.git"
BACKEND_REPO="git@github.com:${GITHUB_USER}/LiveLens_Backend.git"
DEPLOYMENT_REPO="git@github.com:${GITHUB_USER}/livelens_deployment.git"

echo "📥 Cloning repositories..."

# Test SSH connection
echo "🔍 Testing GitHub SSH connection..."
ssh -T git@github.com || echo "SSH connection test completed"

# Clone repositories
if [ ! -d "livelens_deployment" ]; then
    echo "📥 Cloning deployment repository..."
    git clone $DEPLOYMENT_REPO livelens_deployment
fi

if [ ! -d "LiveLens_Backend" ]; then
    echo "📥 Cloning backend repository..."
    git clone $BACKEND_REPO LiveLens_Backend
fi

if [ ! -d "LiveLens_UI" ]; then
    echo "📥 Cloning frontend repository..."
    git clone $FRONTEND_REPO LiveLens_UI
fi

echo "✅ All repositories cloned successfully!"

# Navigate to deployment directory and run main deployment
cd livelens_deployment
chmod +x deploy-hostinger.sh
echo "🚀 Starting main deployment..."
./deploy-hostinger.sh
EOF

chmod +x continue-deployment.sh

echo ""
echo "✅ VPS setup completed!"
echo ""
echo "🎯 Next steps:"
echo "1. Add the SSH public key (shown above) as deploy keys to all 3 GitHub repositories"
echo "2. Run: ./continue-deployment.sh"
echo ""
echo "📝 The public key is also saved in: ~/.ssh/id_rsa.pub"
echo "   You can view it again with: cat ~/.ssh/id_rsa.pub"
