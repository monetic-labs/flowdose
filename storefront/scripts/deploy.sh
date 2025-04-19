#!/bin/bash
set -e

# Load environment variables
cp .env.staging .env

# Install dependencies
echo "Installing dependencies..."
corepack enable
yarn install

# Build the Next.js application
echo "Building Next.js application..."
yarn build

# Restart the service using PM2
if pm2 list | grep -q "medusa-storefront"; then
  echo "Restarting PM2 service..."
  pm2 restart medusa-storefront
else
  echo "Creating PM2 service..."
  pm2 start "yarn start" --name medusa-storefront
  pm2 save
fi

echo "Storefront deployment completed successfully!" 