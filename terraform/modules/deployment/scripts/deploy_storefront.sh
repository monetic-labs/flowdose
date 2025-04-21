#!/bin/bash
set -e

# Get parameters
APP_DIR=${1:-/root/app}
NODE_ENV=${2:-production}

# Log deployment start
echo "Starting Storefront deployment in $APP_DIR for environment $NODE_ENV"

# Make apt-get non-interactive
export DEBIAN_FRONTEND=noninteractive

# Install Node.js, Yarn, and PM2 if not already installed
if ! command -v node &> /dev/null; then
  echo "Installing Node.js..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
  apt-get install -y nodejs --no-install-recommends
fi

# Enable and prepare Corepack for Yarn version management
echo "Setting up Corepack for Yarn version management..."
corepack enable
corepack prepare yarn@4.4.0 --activate

if ! command -v pm2 &> /dev/null; then
  echo "Installing PM2..."
  npm install -g pm2
fi

# Install git if not already installed
if ! command -v git &> /dev/null; then
  echo "Installing git..."
  apt-get update
  apt-get install -y git --no-install-recommends
fi

# Set up the repository
if [ ! -d "$APP_DIR" ]; then
  # Directory doesn't exist, create it and clone
  echo "Creating app directory and cloning repository..."
  mkdir -p $APP_DIR
  cd $APP_DIR
  git clone https://github.com/monetic-labs/flowdose.git .
elif [ ! -d "$APP_DIR/.git" ]; then
  # Directory exists but no git repo, clean and clone
  echo "Cleaning directory and cloning repository..."
  rm -rf $APP_DIR/*
  cd $APP_DIR
  git clone https://github.com/monetic-labs/flowdose.git .
else
  # Git repo exists, just pull latest
  echo "Updating existing repository..."
  cd $APP_DIR
  git fetch
  git reset --hard origin/main
fi

# Navigate to storefront directory if it exists
if [ -d "$APP_DIR/storefront" ]; then
  echo "Changing to storefront directory..."
  cd $APP_DIR/storefront
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