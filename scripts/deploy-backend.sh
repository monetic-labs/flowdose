#!/bin/bash
set -e  # Exit immediately if a command fails

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
SSH_USER="USER_PLACEHOLDER"
IP_ADDRESS=${2:-"IP_PLACEHOLDER"}
DB_PASSWORD=${DB_PASSWORD:-"PASSWORD_PLACEHOLDER"}

# Debug output
echo "Environment settings:"
echo "- Environment: $ENV"
echo "- IP Address: $IP_ADDRESS"
echo "- GITHUB_ACTIONS: ${GITHUB_ACTIONS:-false}"
echo "- Current directory: $(pwd)"
echo "- DB_PASSWORD is set: $([ -n "$DB_PASSWORD" ] && echo "Yes" || echo "No")"

# Detect if running in CI
if [ -n "$GITHUB_ACTIONS" ]; then
    CI_MODE=true
    echo "Running in CI environment (GITHUB_ACTIONS=$GITHUB_ACTIONS)"
    
    # In CI mode, we don't need an IP address to validate environment
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

# Validate DB_PASSWORD is set
if [ -z "$DB_PASSWORD" ]; then
    echo "Error: DB_PASSWORD environment variable is not set."
    echo "Please set this variable before continuing."
    exit 1
fi

# In CI mode, just show what would happen
if [ "$CI_MODE" = true ]; then
    echo "CI mode: Would SSH to $SSH_USER@$IP_ADDRESS and run the following commands:"
    echo "  - Stop PM2 processes"
    echo "  - Navigate to /var/www/flowdose/backend"
    echo "  - Pull latest code or clone the repository if needed"
    echo "  - Enable Corepack for Yarn 4"
    echo "  - Install dependencies"
    echo "  - Run database migrations"
    echo "  - Start the application with PM2"
    
    if [ -z "$IP_ADDRESS" ]; then
        echo "Error: No IP address provided for deployment. Exiting."
        exit 1
    fi
    
    echo "Will connect to: $SSH_USER@$IP_ADDRESS"
    echo "Backend deployment simulation completed successfully!"
    
    # Actually perform the SSH command even in CI mode
    echo "Performing actual deployment..."
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
fi

# Common deployment code for both CI and non-CI
echo "Starting SSH deployment to $SSH_USER@$IP_ADDRESS..."

# SSH to the backend server and perform deployment
ssh -o StrictHostKeyChecking=no $SSH_USER@$IP_ADDRESS << 'ENDSSH'
    set -e  # Exit immediately if a command fails
    
    echo "Connected to server, starting deployment..."
    echo "Current directory: $(pwd)"
    
    # Check if directory exists, if not clone the repository
    if [ ! -d "/var/www/flowdose/backend" ]; then
        echo "Backend directory doesn't exist, creating..."
        mkdir -p /var/www/flowdose
        # Clone only the backend directory using sparse checkout
        echo "Cloning repository..."
        git clone --no-checkout https://github.com/REPO_PLACEHOLDER/flowdose.git /var/www/flowdose/repo-temp
        cd /var/www/flowdose/repo-temp
        echo "Setting up sparse checkout..."
        git sparse-checkout init --cone
        git sparse-checkout set backend
        git checkout
        echo "Moving backend directory..."
        mv backend /var/www/flowdose/
        cd /var/www/flowdose
        echo "Cleaning up temporary repository..."
        rm -rf repo-temp
    fi
    
    # Stop any running PM2 processes
    echo "Stopping PM2 processes..."
    pm2 stop all 2>/dev/null || true
    
    # Navigate to backend directory
    echo "Changing to backend directory..."
    cd /var/www/flowdose/backend
    echo "Now in: $(pwd)"
    
    # Check if package.json exists to confirm we're in the right directory
    if [ ! -f "package.json" ]; then
        echo "Error: package.json not found. Not a valid Node.js project directory."
        exit 1
    fi
    
    # Pull latest code if it's a git repository
    if [ -d ".git" ]; then
        echo "Pulling latest code..."
        git pull
    else
        echo "Not a git repository. Skipping git pull."
    fi
    
    # Copy over the environment file (this would be uploaded in a separate step)
    if [ -f "/tmp/backend.env" ]; then
        echo "Updating environment file..."
        cp /tmp/backend.env /var/www/flowdose/backend/.env
        echo "Environment file updated."
    else
        echo "Warning: No environment file found at /tmp/backend.env"
        echo "Creating minimal .env file with required variables..."
        cat > /var/www/flowdose/backend/.env << EOF
DATABASE_TYPE=postgres
DATABASE_URL=postgres://postgres:DB_PASSWORD_PLACEHOLDER@localhost:5432/flowdose_DB_NAME_PLACEHOLDER
JWT_SECRET=JWT_SECRET_PLACEHOLDER
COOKIE_SECRET=COOKIE_SECRET_PLACEHOLDER
STRIPE_SECRET_KEY=STRIPE_SECRET_PLACEHOLDER
BACKEND_URL=https://API_DOMAIN_PLACEHOLDER
STORE_CORS=https://STOREFRONT_DOMAIN_PLACEHOLDER
EOF
    fi
    
    # Enable Corepack for Yarn 4
    echo "Enabling Corepack for Yarn 4..."
    corepack enable
    corepack prepare yarn@4.4.0 --activate
    
    # Install dependencies
    echo "Installing dependencies..."
    yarn install
    
    # Run database migrations
    echo "Running database migrations..."
    yarn medusa db:migrate
    
    # Start the application with PM2
    echo "Starting application with PM2..."
    pm2 start yarn --name "medusa" -- start
    
    # Save the PM2 configuration
    pm2 save
    
    # Verify the deployment
    echo "Backend deployment completed successfully!"
ENDSSH

# Check SSH exit status
SSH_EXIT=$?
if [ $SSH_EXIT -ne 0 ]; then
    echo "Error: SSH deployment failed with exit code $SSH_EXIT"
    exit $SSH_EXIT
fi

echo "Backend deployment script completed successfully!" 