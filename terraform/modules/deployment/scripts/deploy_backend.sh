#!/bin/bash
set -e

# Get parameters
APP_DIR=${1:-/home/root/app}
NODE_ENV=${2:-production}

# Log deployment start
echo "Starting Backend deployment in $APP_DIR for environment $NODE_ENV"

# Change to app directory
cd $APP_DIR

# Install dependencies
echo "Installing dependencies..."
yarn install

# Build the application
echo "Building application..."
yarn build

# Restart PM2 process if exists, or start a new one
if pm2 show medusa-backend > /dev/null 2>&1; then
  echo "Restarting existing PM2 service..."
  pm2 restart medusa-backend
else
  echo "Creating new PM2 service..."
  pm2 start --name medusa-backend "cd $APP_DIR && yarn medusa start"
fi

echo "Backend deployment completed successfully" 