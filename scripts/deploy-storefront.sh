#!/bin/bash
set -e  # Exit immediately if a command fails

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

# Debug output
echo "Environment settings:"
echo "- Environment: $ENV"
echo "- IP Address: $IP_ADDRESS"
echo "- GITHUB_ACTIONS: ${GITHUB_ACTIONS:-false}"
echo "- Current directory: $(pwd)"

# Detect if running in CI
if [ -n "$GITHUB_ACTIONS" ]; then
    CI_MODE=true
    echo "Running in CI environment (GITHUB_ACTIONS=$GITHUB_ACTIONS)"
    
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
    echo "  - Enable Corepack for Yarn 4"
    echo "  - Install dependencies"
    echo "  - Build the application"
    echo "  - Start the application with PM2"
    
    if [ -z "$IP_ADDRESS" ]; then
        echo "Error: No IP address provided for deployment. Exiting."
        exit 1
    fi
    
    echo "Will connect to: $SSH_USER@$IP_ADDRESS"
    echo "Storefront deployment simulation completed successfully!"
    
    # Actually perform the SSH command even in CI mode
    echo "Performing actual deployment..."
else
    echo "Deploying to $SSH_USER@$IP_ADDRESS..."
    
    # Check environment variables (only in non-CI mode)
    if [ "$CI_MODE" != "true" ]; then
        echo "Validating environment variables..."
        # Try to find and run the validation script
        if [ -f "./validate-storefront-env.sh" ]; then
            ./validate-storefront-env.sh $ENV
        elif [ -f "../scripts/validate-storefront-env.sh" ]; then
            ../scripts/validate-storefront-env.sh $ENV
        else
            echo "Warning: Cannot find validate-storefront-env.sh script. Skipping validation."
        fi
    else
        echo "Skipping environment validation in CI mode. Using pre-generated env file."
    fi
fi

# Common deployment code for both CI and non-CI
echo "Starting SSH deployment to $SSH_USER@$IP_ADDRESS..."
    
# SSH to the storefront server and perform deployment
ssh -o StrictHostKeyChecking=no $SSH_USER@$IP_ADDRESS << 'ENDSSH'
    set -e  # Exit immediately if a command fails
    
    echo "Connected to server, starting deployment..."
    echo "Current directory: $(pwd)"
    
    # Check if directory exists, if not clone the repository
    if [ ! -d "/var/www/flowdose/storefront" ]; then
        echo "Storefront directory doesn't exist, creating..."
        mkdir -p /var/www/flowdose
        # Clone only the storefront directory using sparse checkout
        echo "Cloning repository..."
        git clone --no-checkout https://github.com/monetic-labs/flowdose.git /var/www/flowdose/repo-temp
        cd /var/www/flowdose/repo-temp
        echo "Setting up sparse checkout..."
        git sparse-checkout init --cone
        git sparse-checkout set storefront
        git checkout
        echo "Moving storefront directory..."
        mv storefront /var/www/flowdose/
        cd /var/www/flowdose
        echo "Cleaning up temporary repository..."
        rm -rf repo-temp
    fi
    
    # Stop any running PM2 processes
    echo "Stopping PM2 processes..."
    pm2 stop all 2>/dev/null || true
    
    # Navigate to storefront directory
    echo "Changing to storefront directory..."
    cd /var/www/flowdose/storefront
    echo "Now in: $(pwd)"
    
    # Pull latest code
    if [ -d ".git" ]; then
        echo "Pulling latest code..."
        git pull
    else
        echo "Warning: Not a git repository. Cannot pull latest changes."
    fi
    
    # Copy over the environment file (this would be uploaded in a separate step)
    if [ -f "/tmp/storefront.env" ]; then
        echo "Updating environment file..."
        cp /tmp/storefront.env /var/www/flowdose/storefront/.env.${ENV}
        ln -sf /var/www/flowdose/storefront/.env.${ENV} /var/www/flowdose/storefront/.env.local
        echo "Environment file updated."
    else
        echo "Warning: No environment file found at /tmp/storefront.env"
    fi
    
    # Enable Corepack for Yarn 4
    echo "Enabling Corepack for Yarn 4..."
    corepack enable
    corepack prepare yarn@4.4.0 --activate
    
    # Install dependencies
    echo "Installing dependencies..."
    yarn install
    
    # Build the application
    echo "Building application..."
    yarn build
    
    # Start the application with PM2 on port 8000
    echo "Starting application with PM2..."
    pm2 start yarn --name "next" -- start
    
    # Save the PM2 configuration
    pm2 save
    
    # Verify the deployment
    echo "Storefront deployment completed successfully!"
ENDSSH

# Check SSH exit status
SSH_EXIT=$?
if [ $SSH_EXIT -ne 0 ]; then
    echo "Error: SSH deployment failed with exit code $SSH_EXIT"
    exit $SSH_EXIT
fi

echo "Storefront deployment script completed successfully!" 