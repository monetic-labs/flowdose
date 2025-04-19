#!/bin/bash
# SSL Certificate Setup Script for FlowDose staging servers
# Usage: bash setup-ssl.sh

BACKEND_IP="134.199.223.159"
STOREFRONT_IP="137.184.224.115"
SSH_KEY="~/.ssh/flowdose-do"
SSH_BACKEND="ssh -i $SSH_KEY root@$BACKEND_IP"
SSH_STOREFRONT="ssh -i $SSH_KEY root@$STOREFRONT_IP"

# Install Certbot if not already installed
echo "Ensuring Certbot is installed on Backend server..."
$SSH_BACKEND "apt update && apt install -y certbot python3-certbot-nginx"

# Set up SSL for Backend (API and Admin)
echo "Setting up SSL for Backend server..."
$SSH_BACKEND "certbot --nginx --non-interactive --agree-tos --email admin@flowdose.xyz \
  --domains api-staging.flowdose.xyz,admin-staging.flowdose.xyz \
  --redirect"

# Install Certbot if not already installed
echo "Ensuring Certbot is installed on Storefront server..."
$SSH_STOREFRONT "apt update && apt install -y certbot python3-certbot-nginx"

# Set up SSL for Storefront
echo "Setting up SSL for Storefront server..."
$SSH_STOREFRONT "certbot --nginx --non-interactive --agree-tos --email admin@flowdose.xyz \
  --domains staging.flowdose.xyz \
  --redirect"

echo "SSL setup completed successfully!"
echo ""
echo "Services should now be accessible at:"
echo "- https://staging.flowdose.xyz (Storefront)"
echo "- https://api-staging.flowdose.xyz (Backend API)"
echo "- https://admin-staging.flowdose.xyz (Admin Panel)" 