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
SSH_USER="root"
IP_ADDRESS=${2:-""}

# Debug output
echo "Environment settings:"
echo "- Environment: $ENV"
echo "- IP Address: $IP_ADDRESS"
echo "- GITHUB_ACTIONS: ${GITHUB_ACTIONS:-false}"
echo "- Current directory: $(pwd)"
echo "- DB_PASSWORD set: $(if [ -n "$DB_PASSWORD" ]; then echo "yes"; else echo "no"; fi)"

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
        echo "Error: No IP address provided. Usage: ./deploy-backend.sh [environment] [ip_address]"
        exit 1
    fi
fi

# Check if DB_PASSWORD is set
if [ -z "$DB_PASSWORD" ]; then
    echo "ERROR: DB_PASSWORD environment variable is not set locally. Cannot proceed with deployment."
    echo "Please ensure DB_PASSWORD is set in the environment before running this script."
    exit 1
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
# Export DB_PASSWORD variable so SSH can use it
export DB_PASSWORD
# Use -o SendEnv to pass the DB_PASSWORD environment variable to the remote server
ssh -o StrictHostKeyChecking=no -o SendEnv=DB_PASSWORD $SSH_USER@$IP_ADDRESS << "ENDSSH"
    set -e  # Exit immediately if a command fails
    
    echo "Connected to server, starting deployment..."
    echo "Current directory: $(pwd)"
    echo "Checking DB_PASSWORD: $(if [ -n "$DB_PASSWORD" ]; then echo "set"; else echo "not set"; fi)"
    
    # Check if directory exists, if not clone the repository
    if [ ! -d "/var/www/flowdose/backend" ]; then
        echo "Backend directory doesn't exist, creating..."
        mkdir -p /var/www/flowdose
        # Clone only the backend directory using sparse checkout
        echo "Cloning repository..."
        git clone --no-checkout https://github.com/monetic-labs/flowdose.git /var/www/flowdose/repo-temp
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
    
    # Pull latest code
    if [ -d ".git" ]; then
        echo "Pulling latest code..."
        git pull
    else
        echo "Warning: Not a git repository. Cannot pull latest changes."
    fi
    
    # Copy over the environment file (this would be uploaded in a separate step)
    if [ -f "/tmp/backend.env" ]; then
        echo "Updating environment file..."
        cp /tmp/backend.env /var/www/flowdose/backend/.env.${ENV}
        ln -sf /var/www/flowdose/backend/.env.${ENV} /var/www/flowdose/backend/.env
        echo "Environment file updated."
        
        # Verify database connection settings in the environment file
        echo "Checking database connection settings..."
        if grep -q "DATABASE_URL=" /var/www/flowdose/backend/.env; then
            echo "DATABASE_URL found in environment file."
            # Extract host from DATABASE_URL to check if it's not trying to use localhost
            DB_HOST=$(grep "DATABASE_URL=" /var/www/flowdose/backend/.env | sed -E 's/.*\/\/([^:]+):([^@]+)@([^:]+).*/\3/')
            if [[ "$DB_HOST" == "::1" || "$DB_HOST" == "localhost" || "$DB_HOST" == "127.0.0.1" ]]; then
                echo "WARNING: Database host is set to local ($DB_HOST). It should be set to a remote DigitalOcean database."
                echo "Will override with correct database connection."
                
                # Set the correct database connection for DigitalOcean PostgreSQL
                echo "Setting correct database connection for DigitalOcean PostgreSQL..."
                sed -i 's|DATABASE_URL=.*|DATABASE_URL=postgresql://doadmin:${DB_PASSWORD}@postgres-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25060/defaultdb?sslmode=require|g' /var/www/flowdose/backend/.env
            else
                echo "Database host setting looks correct: $DB_HOST"
            fi
        else
            echo "WARNING: DATABASE_URL not found in environment file. Will set it explicitly."
            # Add the correct DATABASE_URL to the .env file
            echo "Adding correct DATABASE_URL to .env file..."
            echo "DATABASE_URL=postgresql://doadmin:${DB_PASSWORD}@postgres-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25060/defaultdb?sslmode=require" >> /var/www/flowdose/backend/.env
        fi
    else
        echo "Warning: No environment file found at /tmp/backend.env"
        # Create a minimal .env file with the DATABASE_URL
        echo "Creating minimal .env file with DATABASE_URL..."
        echo "DATABASE_URL=postgresql://doadmin:${DB_PASSWORD}@postgres-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25060/defaultdb?sslmode=require" > /var/www/flowdose/backend/.env
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
    
    # Set the correct DATABASE_URL explicitly before running migrations
    echo "Ensuring DATABASE_URL is correctly set for migrations..."
    
    # Make sure we have the password from a secure location (GitHub Secret or environment variable)
    # This should be set in the GitHub workflow that calls this script
    if [ -z "${DB_PASSWORD}" ]; then
        echo "ERROR: DB_PASSWORD environment variable is not set. Cannot connect to database."
        echo "Please ensure this is set in the GitHub workflow or server environment."
        exit 1
    fi
    
    # Log the DATABASE_URL (mask password)
    CURRENT_DB_URL=$(grep "DATABASE_URL=" /var/www/flowdose/backend/.env | cut -d'=' -f2-)
    MASKED_URL=$(echo $CURRENT_DB_URL | sed 's/:[^:]*@/:*****@/')
    echo "Using DATABASE_URL: $MASKED_URL"
    
    # Run database migrations with explicit environment variable from the .env file
    echo "Running database migrations..."
    yarn medusa db:migrate
    
    # Start the application with PM2 in correct mode
    echo "Starting application with PM2..."
    
    # Make sure PM2 uses the correct DATABASE_URL from the .env file
    echo "Ensuring PM2 processes use the correct environment..."
    pm2 start yarn --name "medusa-server" -- start:server
    pm2 start yarn --name "medusa-worker" -- start:worker
    
    # Save the PM2 configuration
    pm2 save
    
    echo "Backend deployment completed successfully!"
ENDSSH

# Check SSH exit status
SSH_EXIT=$?
if [ $SSH_EXIT -ne 0 ]; then
    echo "Error: SSH deployment failed with exit code $SSH_EXIT"
    exit $SSH_EXIT
fi

echo "Backend deployment script completed successfully!" 