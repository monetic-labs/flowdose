#!/bin/bash
set -e

echo "Starting storefront deployment at $(date)"

# Ensure we're in the correct directory
if [ ! -f "package.json" ]; then
  echo "Error: package.json not found. Please run this script from the storefront root directory."
  exit 1
fi

# Load environment variables
echo "Loading environment variables..."
if [ -f .env ]; then
  source .env
  echo "Using existing .env file"
elif [ -f .env.staging ]; then
  echo "Copying .env.staging to .env"
  cp .env.staging .env
  source .env
else
  echo "Error: No .env or .env.staging file found!"
  exit 1
fi

# Install dependencies
echo "Installing dependencies..."
corepack enable || { echo "Failed to enable corepack. Continuing anyway..."; }
NODE_TLS_REJECT_UNAUTHORIZED=0 yarn install || { echo "Failed to install dependencies!"; exit 1; }

# Build the application
echo "Building application..."
NODE_TLS_REJECT_UNAUTHORIZED=0 yarn build || { echo "Failed to build application!"; exit 1; }

# Restart the service using PM2
echo "Configuring PM2 service..."
if pm2 list | grep -q "next-storefront"; then
  echo "Restarting PM2 service..."
  pm2 restart next-storefront || { echo "Failed to restart PM2 service!"; exit 1; }
else
  echo "Creating PM2 service..."
  NODE_ENV=production NODE_TLS_REJECT_UNAUTHORIZED=0 pm2 start "yarn start" --name next-storefront || { echo "Failed to create PM2 service!"; exit 1; }
  pm2 save || { echo "Failed to save PM2 configuration!"; exit 1; }
fi

echo "Ensuring PM2 starts on system boot..."
pm2 startup | grep -v "sudo" || true
pm2 save || true

echo "Storefront deployment completed successfully at $(date)!" 