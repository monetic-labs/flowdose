#!/bin/bash
set -e

# Get parameters
APP_DIR=${1:-/root/app}
NODE_ENV=${2:-production}

# Log deployment start
echo "Starting Storefront deployment in $APP_DIR for environment $NODE_ENV"

# Change to app directory
cd $APP_DIR

# Install dependencies
echo "Installing dependencies..."
yarn install

# Build the application
echo "Building application..."
yarn build

# Restart PM2 process if exists, or start a new one
if pm2 show nextjs-storefront > /dev/null 2>&1; then
  echo "Restarting existing PM2 service..."
  pm2 restart nextjs-storefront
else
  echo "Creating new PM2 service..."
  pm2 start --name nextjs-storefront "cd $APP_DIR && yarn start"
fi

echo "Storefront deployment completed successfully" 