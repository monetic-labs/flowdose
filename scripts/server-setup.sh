#!/bin/bash
# Server setup script for FlowDose staging environment
# Usage: ./scripts/server-setup.sh <IP_ADDRESS> <SERVER_TYPE>
# Example: ./scripts/server-setup.sh 134.199.223.159 backend

set -e

IP_ADDRESS=$1
SERVER_TYPE=$2

if [ -z "$IP_ADDRESS" ] || [ -z "$SERVER_TYPE" ]; then
  echo "Usage: $0 <IP_ADDRESS> <SERVER_TYPE>"
  echo "Example: $0 134.199.223.159 backend"
  exit 1
fi

SSH="ssh -i ~/.ssh/flowdose-do -o StrictHostKeyChecking=no root@$IP_ADDRESS"

# Update system packages
echo "Updating system packages..."
$SSH "apt update && apt upgrade -y"

# Install dependencies
echo "Installing dependencies..."
$SSH "apt install -y curl git nginx build-essential"

# Install Node.js
echo "Installing Node.js..."
$SSH "curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt install -y nodejs"

# Install PM2
echo "Installing PM2..."
$SSH "npm install -g pm2"

# Enable Corepack
echo "Enabling Corepack..."
$SSH "corepack enable"

# Create app directory
echo "Creating app directory..."
$SSH "mkdir -p /home/root/app/scripts && chown -R root:root /home/root/app"

# Configure Nginx
echo "Configuring Nginx..."
if [ "$SERVER_TYPE" == "backend" ]; then
  # Backend Nginx configuration
  $SSH "cat > /etc/nginx/sites-available/flowdose << 'EOL'
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
EOL"
else
  # Storefront Nginx configuration
  $SSH "cat > /etc/nginx/sites-available/flowdose << 'EOL'
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
EOL"
fi

# Enable Nginx site
$SSH "ln -sf /etc/nginx/sites-available/flowdose /etc/nginx/sites-enabled/ && nginx -t && systemctl reload nginx"

# Install Certbot for SSL
echo "Installing Certbot..."
$SSH "apt install -y certbot python3-certbot-nginx"

echo "Server setup completed successfully!"
echo "Don't forget to configure SSL with Certbot after DNS is configured." 