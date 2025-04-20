#!/bin/bash
set -e

# Default environment
ENV=${1:-development}

echo "==================================================="
echo "Starting FlowDose stack in $ENV environment"
echo "==================================================="

# Validate environment
if [[ ! "$ENV" =~ ^(development|staging|production)$ ]]; then
    echo "Error: Invalid environment. Use 'development', 'staging', or 'production'"
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

# Generate publishable key if in development mode
if [ "$ENV" == "development" ]; then
    echo "Generating publishable API key..."
    cd backend && node scripts/generate-publishable-key.js
    cd ..
    
    # Extract and update the publishable key
    KEY=$(cd backend && node -e "
        const fs = require('fs');
        const path = require('path');
        const envFile = path.resolve('../storefront/.env');
        const content = fs.existsSync(envFile) ? fs.readFileSync(envFile, 'utf8') : '';
        const match = content.match(/NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=([a-zA-Z0-9_]+)/);
        if (match) console.log(match[1]);
    ")
    
    if [ -n "$KEY" ]; then
        echo "Using existing publishable key: $KEY"
    else
        echo "Please copy the publishable key from above and add it to storefront/.env"
        read -p "Press Enter to continue..."
    fi
fi

# Start storefront
echo "Starting Next.js storefront..."
cd storefront && bash scripts/start.sh $ENV

# If storefront exits, kill the backend process
kill $BACKEND_PID 2>/dev/null || true 