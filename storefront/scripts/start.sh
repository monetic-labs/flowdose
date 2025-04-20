#!/bin/bash
set -e

# Default environment
ENV=${1:-local}

echo "Starting Next.js storefront in $ENV environment"

# Validate environment
if [[ ! "$ENV" =~ ^(local|staging|production)$ ]]; then
    echo "Error: Invalid environment. Use 'local', 'staging', or 'production'"
    exit 1
fi

# Ensure we're in the correct directory
if [ ! -f "package.json" ]; then
    echo "Error: package.json not found. Please run this script from the storefront root directory."
    exit 1
fi

# Load appropriate .env file
if [ -f .env.$ENV ]; then
    echo "Using environment variables from .env.$ENV"
    cp .env.$ENV .env
elif [ -f .env ]; then
    if [ "$ENV" != "local" ]; then
        echo "Warning: .env.$ENV not found, using existing .env file"
    else
        echo "Using existing .env file"
    fi
else
    echo "Error: No .env or .env.$ENV file found"
    exit 1
fi

# Ensure dependencies are installed
echo "Checking dependencies..."
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    corepack enable
    yarn install
fi

# Configure SSL verification for local/staging
if [ "$ENV" == "local" ] || [ "$ENV" == "staging" ]; then
    export NODE_TLS_REJECT_UNAUTHORIZED=0
    echo "SSL verification disabled for $ENV environment"
fi

# Check for Medusa publishable key
if ! grep -q "NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY" .env; then
    echo "Warning: NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY not found in .env file"
    echo "You may need to generate a publishable key using the backend/scripts/generate-publishable-key.js script"
fi

# Start the appropriate service
if [ "$ENV" == "local" ]; then
    echo "Starting local development server..."
    yarn dev
elif [ "$ENV" == "production" ] || [ "$ENV" == "staging" ]; then
    echo "Building application for $ENV environment..."
    yarn build
    
    echo "Starting $ENV server..."
    NODE_ENV=$ENV yarn start
fi 