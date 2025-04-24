#!/bin/bash
set -e

# Default environment
ENV=${1:-staging}

echo "==================================================="
echo "Deploying FlowDose Backend in $ENV environment"
echo "==================================================="

# Validate environment
if [[ ! "$ENV" =~ ^(staging|production|test)$ ]]; then
    echo "Error: Invalid environment. Use 'staging', 'production', or 'test'"
    exit 1
fi

# SSH variables
SSH_USER="root"
IP_ADDRESS=${2:-""}

# Detect if running in CI
if [ -n "$GITHUB_ACTIONS" ]; then
    CI_MODE=true
    echo "Running in CI environment, will skip SSH operations"
    
    # In CI mode, we don't need an IP address
    if [ -z "$IP_ADDRESS" ]; then
        echo "No IP address provided, but running in CI mode so continuing anyway."
    fi
else
    CI_MODE=false
    
    # Only check for IP address in non-CI mode
    if [ -z "$IP_ADDRESS" ]; then
        echo "Error: No IP address provided. Usage: ./deploy-backend.sh [environment] [ip_address]"
        exit 1
    fi
fi

# In CI mode, just show what would happen
if [ "$CI_MODE" = true ]; then
    echo "Deploying to $ENV environment in CI mode..."
    echo "CI mode: Would SSH to the server and run the following commands:"
    echo "  - Stop PM2 processes"
    echo "  - Navigate to /var/www/flowdose/backend"
    echo "  - Pull latest code from the backend directory"
    echo "  - Enable Corepack for Yarn 4"
    echo "  - Install dependencies"
    echo "  - Build the application"
    echo "  - Run database migrations"
    echo "  - Start the application with PM2"
    
    echo "Backend deployment simulation completed successfully!"
else
    echo "Deploying to $SSH_USER@$IP_ADDRESS..."
    
    # Check environment variables (only in non-CI mode)
    if [ "$CI_MODE" != "true" ]; then
        echo "Validating environment variables..."
        # Try to find and run the validation script
        if [ -f "./validate-backend-env.sh" ]; then
            ./validate-backend-env.sh $ENV
        elif [ -f "../scripts/validate-backend-env.sh" ]; then
            ../scripts/validate-backend-env.sh $ENV
        else
            echo "Warning: Cannot find validate-backend-env.sh script. Skipping validation."
        fi
    else
        echo "Skipping environment validation in CI mode. Using pre-generated env file."
    fi
    
    # SSH to the backend server and perform deployment
    ssh -o StrictHostKeyChecking=no $SSH_USER@$IP_ADDRESS << 'ENDSSH'
        # Check if directory exists, if not clone the repository
        if [ ! -d "/var/www/flowdose/backend" ]; then
            echo "Backend directory doesn't exist, creating..."
            mkdir -p /var/www/flowdose
            # Clone only the backend directory using sparse checkout
            git clone --no-checkout https://github.com/monetic-labs/flowdose.git /var/www/flowdose/repo-temp
            cd /var/www/flowdose/repo-temp
            git sparse-checkout init --cone
            git sparse-checkout set backend
            git checkout
            mv backend /var/www/flowdose/
            cd /var/www/flowdose
            rm -rf repo-temp
        fi
        
        # Stop any running PM2 processes
        pm2 stop all || true
        
        # Navigate to backend directory
        cd /var/www/flowdose/backend
        
        # Pull latest code
        if [ -d ".git" ]; then
            git pull
        else
            echo "Warning: Not a git repository. Cannot pull latest changes."
        fi
        
        # Copy over the environment file (this would be uploaded in a separate step)
        if [ -f "/tmp/backend.env" ]; then
            cp /tmp/backend.env /var/www/flowdose/backend/.env.${ENV}
            ln -sf /var/www/flowdose/backend/.env.${ENV} /var/www/flowdose/backend/.env
            echo "Environment file updated."
        fi
        
        # Enable Corepack for Yarn 4
        echo "Enabling Corepack for Yarn 4..."
        corepack enable
        corepack prepare yarn@4.4.0 --activate
        
        # Install dependencies
        yarn install
        
        # Build the application
        yarn build
        
        # Run database migrations
        yarn medusa migrations run
        
        # Start the application with PM2 in correct mode
        pm2 start yarn --name "medusa-server" -- start:server
        pm2 start yarn --name "medusa-worker" -- start:worker
        
        # Save the PM2 configuration
        pm2 save
        
        echo "Backend deployment completed successfully!"
ENDSSH
fi

echo "Backend deployment script completed." 