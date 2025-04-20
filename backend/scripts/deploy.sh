#!/bin/bash

# Medusa Backend Deployment Script
# This script is used to deploy the Medusa backend to the server.

set -e

echo "Starting backend deployment at $(date)"

# Ensure we're in the correct directory
if [ ! -f "package.json" ]; then
  echo "Error: package.json not found. Please run this script from the backend root directory."
  exit 1
fi

# Load environment variables from .env.staging file if it exists
if [ -f ".env.staging" ]; then
  echo "Loading environment variables from .env.staging"
  export $(grep -v '^#' .env.staging | xargs)
else
  echo "No .env.staging file found, using existing environment variables"
fi

# Install dependencies
echo "Installing dependencies..."
yarn install

# Run database migrations with SSL verification disabled
echo "Running database migrations with SSL verification disabled..."
NODE_TLS_REJECT_UNAUTHORIZED=0 yarn medusa db:migrate || { echo "Failed to run database migrations!"; exit 1; }

# Build the application
echo "Building the application..."
yarn build

# Check if build output directory exists
if [ ! -d ".medusa/server" ]; then
  echo "Build output directory .medusa/server does not exist! Build failed."
  exit 1
fi

# Install dependencies in the build output directory as per Medusa docs
echo "Installing dependencies in build output directory..."
cd .medusa/server
yarn install
cd ../..

# Copy environment variables to build directory
echo "Copying environment variables to build directory..."
if [ -f ".env.staging" ]; then
  cp .env.staging .medusa/server/.env
fi

# Manage the PM2 service
echo "Managing PM2 service..."

# Stop the existing service if running
pm2 stop medusa-backend || true

# Start the service from the build directory
echo "Starting PM2 service from build directory..."
pm2 start --name medusa-backend "cd .medusa/server && yarn run start" || {
  echo "Failed to start service!"
  exit 1
}

# Wait for the service to start
echo "Waiting for service to start..."
sleep 30

# Generate publishable key
echo "Generating publishable key..."
node scripts/generate-publishable-key.js || {
  echo "Warning: Failed to generate publishable key, but deployment can continue."
  echo "You can manually generate a key later with: node scripts/generate-publishable-key.js"
}

echo "Backend deployment completed successfully at $(date)!"
exit 0 