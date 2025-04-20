#!/bin/bash
set -e

# Default environment
ENV=${1:-local}

echo "==================================================="
echo "Starting FlowDose stack in $ENV environment"
echo "==================================================="

# Validate environment
if [[ ! "$ENV" =~ ^(local|staging|production)$ ]]; then
    echo "Error: Invalid environment. Use 'local', 'staging', or 'production'"
    exit 1
fi

# Check if we're in the root directory
if [ ! -d "backend" ] || [ ! -d "storefront" ]; then
    echo "Error: backend or storefront directory not found. Please run this script from the project root."
    exit 1
fi

# Start backend in background
echo "Starting Medusa backend..."
(cd backend && bash scripts/start.sh $ENV) &
BACKEND_PID=$!

# Wait for backend to initialize (10 seconds)
echo "Waiting for backend to initialize..."
sleep 10

# Generate publishable key if in local mode
if [ "$ENV" == "local" ]; then
    # Check if the key is already set in the storefront .env
    if [ -f "storefront/.env" ] && grep -q "NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY" "storefront/.env"; then
        echo "Publishable API key already exists in storefront/.env"
    else
        echo "Generating publishable API key..."
        # We continue even if the key generation fails to at least start the storefront
        (cd backend && node scripts/generate-publishable-key.js || true)
        
        # If we couldn't generate a key, create a placeholder for local development
        if ! grep -q "NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY" "storefront/.env" 2>/dev/null; then
            echo "Using a placeholder publishable key for local development"
            PLACEHOLDER_KEY="pk_test_$(date +%s | sha256sum | base64 | head -c 12)"
            echo "NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=$PLACEHOLDER_KEY" >> "storefront/.env"
        fi
    fi
fi

# Start storefront
echo "Starting Next.js storefront..."
cd storefront && bash scripts/start.sh $ENV

# If storefront exits, kill the backend process
echo "Shutting down backend process..."
kill $BACKEND_PID 2>/dev/null || true 