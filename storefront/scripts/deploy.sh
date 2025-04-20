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

# Check for publishable key and try to get one from the backend if missing
if ! grep -q "NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY" .env || grep -q "NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=pk_staging_temp" .env; then
  echo "No valid publishable key found in .env, attempting to fetch from backend..."
  
  # Try to fetch publishable key from backend
  # Assumes the backend is running on localhost:9000 in local dev or on api-staging.flowdose.xyz in staging
  BACKEND_URL="http://localhost:9000"
  if [ -n "$NODE_ENV" ] && [ "$NODE_ENV" = "production" ]; then
    BACKEND_URL="https://api-staging.flowdose.xyz"
  fi
  
  # Attempt to generate a key using generate-publishable-key script if available
  if [ -f "../backend/scripts/generate-publishable-key.js" ]; then
    echo "Using backend script to generate publishable key..."
    NODE_TLS_REJECT_UNAUTHORIZED=0 MEDUSA_URL=$BACKEND_URL node ../backend/scripts/generate-publishable-key.js || true
  fi
  
  # If still no key, use a placeholder
  if ! grep -q "NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY" .env || grep -q "NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=pk_staging_temp" .env; then
    echo "Using placeholder publishable key for build..."
    PLACEHOLDER_KEY="pk_placeholder_$(date +%s | md5sum | head -c 8)"
    sed -i.bak "/NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=/d" .env
    echo "NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=$PLACEHOLDER_KEY" >> .env
  fi
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