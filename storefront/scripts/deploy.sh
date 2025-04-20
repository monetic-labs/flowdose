#!/bin/bash

# Storefront Deployment Script
# This script is used to deploy the Next.js storefront to the server.

set -e

echo "Starting storefront deployment at $(date)"

# Ensure we're in the correct directory
if [ ! -f "package.json" ]; then
  echo "Error: package.json not found. Please run this script from the storefront root directory."
  exit 1
fi

# Load environment variables from .env.staging file if it exists
if [ -f ".env.staging" ]; then
  echo "Loading environment variables from .env.staging"
  export $(grep -v '^#' .env.staging | xargs)
else
  echo "No .env.staging file found, using existing environment variables"
fi

# Determine environment
ENVIRONMENT=${NODE_ENV:-development}
if [ "$ENVIRONMENT" == "production" ] || [ "$ENVIRONMENT" == "staging" ]; then
  IS_PROD_OR_STAGING=true
else
  IS_PROD_OR_STAGING=false
fi

# Check for publishable key and try to get one from the backend if missing
if ! grep -q "NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY" .env || grep -q "NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=pk_" .env | grep -v "pk_test_\|pk_live_"; then
  echo "No valid publishable key found in .env, attempting to fetch from backend..."
  
  # Try to fetch publishable key from backend
  # Assumes the backend is running on localhost:9000 in local dev or on api-staging.flowdose.xyz in staging
  BACKEND_URL="http://localhost:9000"
  if [ "$IS_PROD_OR_STAGING" = true ]; then
    BACKEND_URL="https://api-staging.flowdose.xyz"
  fi
  
  # Attempt to generate a key using generate-publishable-key script if available
  if [ -f "../backend/scripts/generate-publishable-key.js" ]; then
    echo "Using backend script to generate publishable key..."
    NODE_TLS_REJECT_UNAUTHORIZED=0 MEDUSA_URL=$BACKEND_URL node ../backend/scripts/generate-publishable-key.js || true
  fi
  
  # If still no key, use a placeholder for development only
  if ! grep -q "NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY" .env || grep -q "NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=pk_" .env | grep -v "pk_test_\|pk_live_"; then
    if [ "$IS_PROD_OR_STAGING" = true ]; then
      echo "ERROR: Unable to obtain a valid publishable key for production/staging environment."
      echo "The application will not function correctly without a valid key."
      echo "Please ensure the backend is running and accessible, then try again."
      exit 1
    else
      echo "Using placeholder publishable key for local development build..."
      PLACEHOLDER_KEY="pk_local_$(date +%s | md5sum | head -c 12)"
      sed -i.bak "/NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=/d" .env
      echo "NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=$PLACEHOLDER_KEY" >> .env
      echo "Added placeholder key: $PLACEHOLDER_KEY"
      echo "WARNING: This is a placeholder key for development only and will not work in production."
    fi
  fi
fi

# Display the key being used (first 5 chars only for security)
KEY_VALUE=$(grep "NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY" .env | cut -d'=' -f2)
echo "Using publishable key: ${KEY_VALUE:0:5}*****"

# Install dependencies
echo "Installing dependencies..."
yarn install

# Build the application
echo "Building the application..."
yarn build

# Check if build output directory exists
if [ ! -d ".next" ]; then
  echo "Build output directory .next does not exist! Build failed."
  exit 1
fi

# Manage the PM2 service
echo "Managing PM2 service..."

# Stop the existing service if running
pm2 stop flowdose-storefront || true

# Start the service
echo "Starting PM2 service..."
pm2 start --name flowdose-storefront "yarn start" || {
  echo "Failed to start service!"
  exit 1
}

echo "Storefront deployment completed successfully at $(date)!"
exit 0 