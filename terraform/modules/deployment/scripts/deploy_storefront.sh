#!/bin/bash
set -e

# Get parameters
APP_DIR=${1:-/root/app}
NODE_ENV=${2:-production}

# Log deployment start
echo "Starting Storefront deployment in $APP_DIR for environment $NODE_ENV"

# Install Node.js, Yarn, and PM2 if not already installed
if ! command -v node &> /dev/null; then
  echo "Installing Node.js..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
  apt-get install -y nodejs
fi

if ! command -v yarn &> /dev/null; then
  echo "Installing Yarn..."
  npm install -g yarn
fi

if ! command -v pm2 &> /dev/null; then
  echo "Installing PM2..."
  npm install -g pm2
fi

# Change to app directory
cd $APP_DIR

# Clone repository if not exists
if [ ! -f "$APP_DIR/package.json" ]; then
  echo "Cloning repository..."
  git clone https://github.com/monetic-labs/flowdose.git .
  cd storefront
fi

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