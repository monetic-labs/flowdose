#!/bin/bash
set -e

# Default environment
ENV=${1:-local}

echo "Starting Medusa backend in $ENV environment"

# Validate environment
if [[ ! "$ENV" =~ ^(local|staging|production)$ ]]; then
    echo "Error: Invalid environment. Use 'local', 'staging', or 'production'"
    exit 1
fi

# Ensure we're in the correct directory
if [ ! -f "package.json" ]; then
    echo "Error: package.json not found. Please run this script from the backend root directory."
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

# Build if needed for production or staging
if [ "$ENV" == "production" ] || [ "$ENV" == "staging" ]; then
    echo "Building application for $ENV..."
    yarn build
fi

# Configure SSL verification
if [ "$ENV" == "local" ] || [ "$ENV" == "staging" ]; then
    export NODE_TLS_REJECT_UNAUTHORIZED=0
    echo "SSL verification disabled for $ENV environment"
fi

# Set port based on environment
if [ "$ENV" == "production" ]; then
    PORT=9000
elif [ "$ENV" == "staging" ]; then
    PORT=9000
else
    PORT=9000  # Default for local
fi

# Start the appropriate service
if [ "$ENV" == "local" ]; then
    echo "Starting local development server..."
    yarn medusa develop
else
    echo "Starting $ENV server on port $PORT..."
    NODE_ENV=$ENV PORT=$PORT yarn medusa start
fi