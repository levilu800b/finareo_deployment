#!/bin/bash

# =============================================================================
# Quick LiveLens Setup for Hostinger VPS
# Run this script on your VPS as root
# =============================================================================

set -e

echo "🚀 Starting LiveLens setup for livelens.space..."

# Update system first
echo "📦 Updating system..."
apt update && apt upgrade -y

# Install git if not present
apt install -y git

# Clone the repository
echo "📥 Cloning LiveLens repository..."
mkdir -p /opt/livelens
cd /opt/livelens

# Remove existing directory if it exists
rm -rf LiveLens_UI

# Clone the repository
git clone https://github.com/levilu800b/LiveLens_UI.git .

# Navigate to deployment directory
cd livelens_deployment

# Make deployment script executable
chmod +x deploy-hostinger.sh

echo "✅ Repository cloned successfully!"
echo ""
echo "🎯 Next steps:"
echo "1. Run the deployment script:"
echo "   cd /opt/livelens/livelens_deployment"
echo "   ./deploy-hostinger.sh"
echo ""
echo "2. This will:"
echo "   - Install Docker and required packages"
echo "   - Set up SSL certificates"
echo "   - Build and start all services"
echo "   - Create admin user"
echo "   - Display important credentials"
echo ""
echo "⚠️  IMPORTANT: Save the credentials that will be displayed!"
echo ""
echo "Ready to proceed? Run: ./deploy-hostinger.sh"
