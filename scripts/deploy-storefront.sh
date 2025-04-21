#!/bin/bash
set -e

# Default environment
ENV=${1:-staging}

echo "==================================================="
echo "Deploying FlowDose Storefront in $ENV environment"
echo "==================================================="

# Validate environment
if [[ ! "$ENV" =~ ^(staging|production)$ ]]; then
    echo "Error: Invalid environment. Use 'staging' or 'production'"
    exit 1
fi

# SSH variables
SSH_USER="root"
IP_ADDRESS=${2:-""}

if [ -z "$IP_ADDRESS" ]; then
    echo "Error: No IP address provided. Usage: ./deploy-storefront.sh [environment] [ip_address]"
    exit 1
fi

# Detect if running in CI
if [ -n "$GITHUB_ACTIONS" ]; then
    CI_MODE=true
    echo "Running in CI environment, will skip SSH operations"
else
    CI_MODE=false
fi

echo "Deploying to $SSH_USER@$IP_ADDRESS..."

# In CI mode, just show what would happen
if [ "$CI_MODE" = true ]; then
    echo "CI mode: Would SSH to $SSH_USER@$IP_ADDRESS and run the following commands:"
    echo "  - Stop PM2 processes"
    echo "  - Navigate to /var/www/flowdose/storefront"
    echo "  - Pull latest code"
    echo "  - Install dependencies"
    echo "  - Build the application"
    echo "  - Start the application with PM2"
    
    echo "Storefront deployment simulation completed successfully!"
else
    # SSH to the storefront server and perform deployment
    ssh -o StrictHostKeyChecking=no $SSH_USER@$IP_ADDRESS << 'EOF'
        # Stop any running PM2 processes
        pm2 stop all || true
        
        # Navigate to storefront directory
        cd /var/www/flowdose/storefront
        
        # Pull latest code
        git pull
        
        # Install dependencies
        npm ci
        
        # Build the application
        npm run build
        
        # Start the application with PM2 on port 8000
        pm2 start npm --name "next" -- start
        
        # Save the PM2 configuration
        pm2 save
        
        # Verify the deployment
        echo "Storefront deployment completed successfully!"
EOF
fi

echo "Storefront deployment script completed." 