#!/bin/bash
set -e

# Default environment
ENV=${1:-staging}

echo "==================================================="
echo "Deploying FlowDose Storefront in $ENV environment"
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
        echo "Error: No IP address provided. Usage: ./deploy-storefront.sh [environment] [ip_address]"
        exit 1
    fi
fi

# In CI mode, just show what would happen
if [ "$CI_MODE" = true ]; then
    echo "CI mode: Would SSH to $SSH_USER@$IP_ADDRESS and run the following commands:"
    echo "  - Stop PM2 processes"
    echo "  - Navigate to /var/www/flowdose/storefront"
    echo "  - Pull latest code from the storefront directory"
    echo "  - Install dependencies"
    echo "  - Build the application"
    echo "  - Start the application with PM2"
    
    echo "Storefront deployment simulation completed successfully!"
else
    echo "Deploying to $SSH_USER@$IP_ADDRESS..."
    
    # Check environment variables
    echo "Validating environment variables..."
    # This script will create a .env file from GitHub secrets in CI
    # or validate existing .env file in manual deployment
    ./scripts/validate-storefront-env.sh $ENV
    
    # SSH to the storefront server and perform deployment
    ssh -o StrictHostKeyChecking=no $SSH_USER@$IP_ADDRESS << 'ENDSSH'
        # Check if directory exists, if not clone the repository
        if [ ! -d "/var/www/flowdose/storefront" ]; then
            echo "Storefront directory doesn't exist, creating..."
            mkdir -p /var/www/flowdose
            # Clone only the storefront directory using sparse checkout
            git clone --no-checkout https://github.com/yourusername/flowdose.git /var/www/flowdose/repo-temp
            cd /var/www/flowdose/repo-temp
            git sparse-checkout init --cone
            git sparse-checkout set storefront
            git checkout
            mv storefront /var/www/flowdose/
            cd /var/www/flowdose
            rm -rf repo-temp
        fi
        
        # Stop any running PM2 processes
        pm2 stop all || true
        
        # Navigate to storefront directory
        cd /var/www/flowdose/storefront
        
        # Pull latest code
        if [ -d ".git" ]; then
            git pull
        else
            echo "Warning: Not a git repository. Cannot pull latest changes."
        fi
        
        # Copy over the environment file (this would be uploaded in a separate step)
        if [ -f "/tmp/storefront.env" ]; then
            cp /tmp/storefront.env /var/www/flowdose/storefront/.env.${ENV}
            ln -sf /var/www/flowdose/storefront/.env.${ENV} /var/www/flowdose/storefront/.env.local
            echo "Environment file updated."
        fi
        
        # Install dependencies
        yarn install
        
        # Build the application
        yarn build
        
        # Start the application with PM2 on port 8000
        pm2 start yarn --name "next" -- start
        
        # Save the PM2 configuration
        pm2 save
        
        # Verify the deployment
        echo "Storefront deployment completed successfully!"
ENDSSH
fi

echo "Storefront deployment script completed." 