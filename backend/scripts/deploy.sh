#!/bin/bash
set -e

# Load environment variables
source .env.staging

# Install dependencies
echo "Installing dependencies..."
corepack enable
yarn install

# Run database migrations
echo "Running database migrations..."
yarn medusa migrations run

# Build the application
echo "Building application..."
yarn build

# Restart the service using PM2
if pm2 list | grep -q "medusa-backend"; then
  echo "Restarting PM2 service..."
  pm2 restart medusa-backend
else
  echo "Creating PM2 service..."
  pm2 start "yarn start" --name medusa-backend
  pm2 save
fi

echo "Backend deployment completed successfully!" 