#!/bin/bash
set -e

# Default environment
ENV=${1:-staging}

echo "==================================================="
echo "Deploying FlowDose Backend in $ENV environment"
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
    echo "Error: No IP address provided. Usage: ./deploy-backend.sh [environment] [ip_address]"
    exit 1
fi

echo "Deploying to $SSH_USER@$IP_ADDRESS..."

# SSH to the backend server and perform deployment
ssh -o StrictHostKeyChecking=no $SSH_USER@$IP_ADDRESS << 'EOF'
    # Stop any running PM2 processes
    pm2 stop all || true
    
    # Navigate to backend directory
    cd /var/www/flowdose/backend
    
    # Pull latest code
    git pull
    
    # Install dependencies
    npm ci
    
    # Build the application
    npm run build
    
    # Run database migrations
    npx medusa migrations run
    
    # Seed the database if needed
    # Uncomment if needed: npm run seed
    
    # Start the application with PM2
    pm2 start npm --name "medusa" -- start
    
    # Save the PM2 configuration
    pm2 save
    
    echo "Backend deployment completed successfully!"
EOF

echo "Backend deployment script completed." 