#!/bin/bash
# Comprehensive setup script for FlowDose staging servers
# Usage: bash setup-staging.sh

BACKEND_IP="134.199.223.159"
STOREFRONT_IP="137.184.224.115"
SSH_KEY="~/.ssh/flowdose-do"
SSH_BACKEND="ssh -i $SSH_KEY root@$BACKEND_IP"
SSH_STOREFRONT="ssh -i $SSH_KEY root@$STOREFRONT_IP"

echo "Setting up Backend server..."
# Create app directory
$SSH_BACKEND "mkdir -p /home/root/app/scripts"

# Create Nginx configuration
echo "Creating Nginx configuration for Backend..."
$SSH_BACKEND "cat > /etc/nginx/sites-available/flowdose << 'EOF'
server {
    listen 80;
    server_name api-staging.flowdose.xyz admin-staging.flowdose.xyz;

    location / {
        proxy_pass http://localhost:9000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF"

# Enable site and reload Nginx
$SSH_BACKEND "ln -sf /etc/nginx/sites-available/flowdose /etc/nginx/sites-enabled/"
$SSH_BACKEND "rm -f /etc/nginx/sites-enabled/default"
$SSH_BACKEND "nginx -t && systemctl reload nginx"

echo "Setting up Storefront server..."
# Create app directory
$SSH_STOREFRONT "mkdir -p /home/root/app/scripts"

# Install dependencies
echo "Installing dependencies on Storefront server..."
$SSH_STOREFRONT "apt update && apt install -y curl git nginx build-essential"
$SSH_STOREFRONT "curl -fsSL https://deb.nodesource.com/setup_20.x | bash -"
$SSH_STOREFRONT "apt install -y nodejs"
$SSH_STOREFRONT "npm install -g pm2"
$SSH_STOREFRONT "corepack enable"

# Create Nginx configuration
echo "Creating Nginx configuration for Storefront..."
$SSH_STOREFRONT "cat > /etc/nginx/sites-available/flowdose << 'EOF'
server {
    listen 80;
    server_name staging.flowdose.xyz;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF"

# Enable site and reload Nginx
$SSH_STOREFRONT "ln -sf /etc/nginx/sites-available/flowdose /etc/nginx/sites-enabled/"
$SSH_STOREFRONT "rm -f /etc/nginx/sites-enabled/default"
$SSH_STOREFRONT "nginx -t && systemctl reload nginx"

echo "Setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Configure DNS records as described in scripts/dns-setup.md"
echo "2. Set up SSL certificates with Let's Encrypt after DNS propagation"
echo "3. Update GitHub Secrets with the following values:"
echo "   - STAGING_SSH_PRIVATE_KEY: Your SSH private key"
echo "   - STAGING_SSH_USER: root"
echo "   - STAGING_BACKEND_HOST: $BACKEND_IP"
echo "   - STAGING_STOREFRONT_HOST: $STOREFRONT_IP"
echo "4. Push your code to the staging branch to trigger deployment" 