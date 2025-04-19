#!/bin/bash
set -e

# Load environment variables
if [ -f .env ]; then
  source .env
elif [ -f .env.staging ]; then
  cp .env.staging .env
  source .env
fi

# Install dependencies
echo "Installing dependencies..."
corepack enable
NODE_TLS_REJECT_UNAUTHORIZED=0 yarn install

# Build the application
echo "Building application..."
NODE_TLS_REJECT_UNAUTHORIZED=0 yarn build

# Restart the service using PM2
if pm2 list | grep -q "next-storefront"; then
  echo "Restarting PM2 service..."
  pm2 restart next-storefront
else
  echo "Creating PM2 service..."
  NODE_ENV=production NODE_TLS_REJECT_UNAUTHORIZED=0 pm2 start "yarn start" --name next-storefront
  pm2 save
fi

echo "Storefront deployment completed successfully!" 