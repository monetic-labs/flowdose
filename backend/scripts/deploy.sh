#!/bin/bash
set -e

echo "Starting backend deployment at $(date)"

# Ensure we're in the correct directory
if [ ! -f "package.json" ]; then
  echo "Error: package.json not found. Please run this script from the backend root directory."
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

# Run database migrations with SSL verification disabled
echo "Running database migrations with SSL verification disabled..."
NODE_TLS_REJECT_UNAUTHORIZED=0 yarn medusa db:migrate || { echo "Failed to run database migrations!"; exit 1; }

# Build the application
echo "Building application..."
NODE_TLS_REJECT_UNAUTHORIZED=0 yarn build || { echo "Failed to build application!"; exit 1; }

# Restart the service using PM2
echo "Configuring PM2 service..."
if pm2 list | grep -q "medusa-backend"; then
  echo "Restarting PM2 service..."
  pm2 restart medusa-backend || { echo "Failed to restart PM2 service!"; exit 1; }
else
  echo "Creating PM2 service..."
  NODE_ENV=production PORT=9000 NODE_TLS_REJECT_UNAUTHORIZED=0 pm2 start "yarn medusa start --port 9000" --name medusa-backend || { echo "Failed to create PM2 service!"; exit 1; }
  pm2 save || { echo "Failed to save PM2 configuration!"; exit 1; }
fi

# Ensure PM2 starts on system boot
echo "Ensuring PM2 starts on system boot..."
pm2 startup | grep -v "sudo" || true
pm2 save || true

# Attempt to generate publishable API key, but don't fail deployment if it doesn't work
if [ -f "scripts/generate-publishable-key.js" ]; then
  echo "Attempting to generate publishable API key (optional)..."
  {
    # Try to generate key, but don't let it block deployment
    echo "Waiting briefly for service to initialize..."
    sleep 10
    NODE_TLS_REJECT_UNAUTHORIZED=0 node scripts/generate-publishable-key.js
    echo "Publishable key generation attempted - check logs for result"
  } || {
    echo "Note: Could not generate publishable key automatically."
    echo "You can manually create one later via the admin dashboard."
  }
fi

echo "Backend deployment completed successfully at $(date)!" 