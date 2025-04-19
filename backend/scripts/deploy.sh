#!/bin/bash
set -e

# Load environment variables
if [ -f .env ]; then
  source .env
elif [ -f .env.staging ]; then
  cp .env.staging .env
  source .env
fi

# Install dependencies
echo "Installing dependencies..."
corepack enable
NODE_TLS_REJECT_UNAUTHORIZED=0 yarn install

# Run database migrations with SSL verification disabled
echo "Running database migrations with SSL verification disabled..."
NODE_TLS_REJECT_UNAUTHORIZED=0 yarn medusa db:migrate

# Build the application
echo "Building application..."
NODE_TLS_REJECT_UNAUTHORIZED=0 yarn build

# Create placeholder admin UI file if it doesn't exist
echo "Setting up admin placeholder..."
mkdir -p public/admin
if [ ! -f public/admin/index.html ]; then
  echo '<html><body>Admin UI Placeholder</body></html>' > public/admin/index.html
fi

# Restart the service using PM2
if pm2 list | grep -q "medusa-backend"; then
  echo "Restarting PM2 service..."
  pm2 restart medusa-backend
else
  echo "Creating PM2 service..."
  NODE_ENV=production PORT=9000 NODE_TLS_REJECT_UNAUTHORIZED=0 pm2 start "yarn medusa start --port 9000" --name medusa-backend
  pm2 save
fi

echo "Backend deployment completed successfully!" 