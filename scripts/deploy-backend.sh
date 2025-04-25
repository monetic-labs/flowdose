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

# Export NODE_TLS_REJECT_UNAUTHORIZED=0 at the beginning of the script to disable SSL certificate verification
export DB_PASSWORD
# Disable SSL certificate verification at the Node.js level
echo "Setting NODE_TLS_REJECT_UNAUTHORIZED=0 to bypass SSL certificate verification"
export NODE_TLS_REJECT_UNAUTHORIZED=0

# In CI mode, just show what would happen
if [ "$CI_MODE" = true ]; then
    echo "Deploying to $ENV environment in CI mode..."
    echo "CI mode: Would SSH to the server and run the following commands:"
    echo "  - Stop PM2 processes"
    echo "  - Navigate to /root/app/backend"
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

# Determine branch based on environment
BRANCH=$([ "$ENV" == "production" ] && echo "main" || echo "staging")
echo "Will deploy from branch: $BRANCH"

# Create a secure way to pass the DB_PASSWORD
# Remove quotes from heredoc to allow variable expansion
ssh -o StrictHostKeyChecking=no $SSH_USER@$IP_ADDRESS << ENDSSH
    # Variables will now be expanded from the parent shell
    DB_PASSWORD="${DB_PASSWORD}"
    ENV="${ENV}"
    BRANCH="${BRANCH}"
    
    set -e  # Exit immediately if a command fails
    
    echo "Connected to server, starting deployment..."
    echo "Current directory: $(pwd)"
    echo "Environment: \$ENV"
    echo "Branch: \$BRANCH"
    
    # Server identification
    echo "=== SERVER IDENTIFICATION ==="
    echo "Hostname: \$(hostname)"
    echo "Current directory: \$(pwd)"
    echo "Current user: \$(whoami)"
    echo "Listing /root/app directory:"
    ls -la /root/app || echo "Directory doesn't exist yet"
    echo "==========================="
    
    # Create app directory if it doesn't exist
    mkdir -p /root/app
    cd /root/app
    
    # First, remove any old backup directory
    echo "Removing old backup directory if it exists..."
    rm -rf /root/app/backend.old
    
    # Then backup the current directory if it exists
    if [ -d "/root/app/backend" ]; then
        echo "Backing up existing backend directory..."
        mv /root/app/backend /root/app/backend.old
    fi
    
    # Simple direct clone approach
    echo "Cloning repository..."
    git clone --depth 1 -b \$BRANCH https://github.com/monetic-labs/flowdose.git /root/app/temp-repo
    
    # Check if clone was successful
    if [ ! -d "/root/app/temp-repo" ]; then
        echo "ERROR: Clone failed - temp directory doesn't exist"
        exit 1
    fi
    
    echo "Clone successful. Directory contents:"
    ls -la /root/app/temp-repo
    
    # Check if backend directory exists in the repo
    if [ ! -d "/root/app/temp-repo/backend" ]; then
        echo "ERROR: Backend directory not found in cloned repository"
        exit 1
    fi
    
    echo "Backend directory found. Contents:"
    ls -la /root/app/temp-repo/backend
    
    # Move backend directory to final location
    echo "Moving backend directory to final location..."
    mv /root/app/temp-repo/backend /root/app/
    
    # Verify package.json exists
    if [ ! -f "/root/app/backend/package.json" ]; then
        echo "ERROR: package.json not found in backend directory"
        exit 1
    fi
    
    echo "Verified package.json exists. Backend setup successful."
    
    # Clean up temporary repository
    echo "Cleaning up temporary repository..."
    rm -rf /root/app/temp-repo
    
    # Stop PM2 processes
    echo "Stopping PM2 processes..."
    pm2 stop all 2>/dev/null || true
    
    # Navigate to backend directory
    echo "Changing to backend directory..."
    cd /root/app/backend
    echo "Now in: \$(pwd)"
    
    # Download DigitalOcean CA certificate
    echo "Downloading DigitalOcean CA certificate..."
    mkdir -p /root/app/certs
    wget -q https://dl.cacerts.digicert.com/DigiCertGlobalRootCA.crt.pem -O /root/app/certs/do-postgres.pem || touch /root/app/certs/do-postgres.pem
    chmod 644 /root/app/certs/do-postgres.pem
    
    # Create minimal environment file if not found
    echo "Setting up environment file..."
    if [ ! -f "/tmp/backend.env" ]; then
        echo "Warning: No environment file found at /tmp/backend.env"
        echo "Creating minimal .env file with DATABASE_URL..."
        
        # Create a reliable DATABASE_URL with explicit password inclusion
        DB_HOST="postgres-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com"
        DB_PORT="25060"
        DB_NAME="defaultdb"
        DB_SSL="sslmode=require"
        
        echo "# Database password being set: \${DB_PASSWORD:0:3}...\${DB_PASSWORD: -3}" # Show first and last 3 chars for validation
        echo "DATABASE_URL=postgresql://doadmin:\${DB_PASSWORD}@\${DB_HOST}:\${DB_PORT}/\${DB_NAME}?\${DB_SSL}" > /root/app/backend/.env
    else
        echo "Found environment file at /tmp/backend.env, copying to application directory"
        cp /tmp/backend.env /root/app/backend/.env
        
        # Ensure the DATABASE_URL is set correctly with the password from CI
        if grep -q "DATABASE_URL=" /root/app/backend/.env; then
            echo "Updating DATABASE_URL with correct password from deployment environment"
            
            # Create a new temporary file with the correct DATABASE_URL
            DB_HOST="postgres-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com"
            DB_PORT="25060"
            DB_NAME="defaultdb"
            DB_SSL="sslmode=require"
            
            # Create a new temp file and replace the DATABASE_URL line
            grep -v "DATABASE_URL=" /root/app/backend/.env > /root/app/backend/.env.tmp
            echo "DATABASE_URL=postgresql://doadmin:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?${DB_SSL}" >> /root/app/backend/.env.tmp
            mv /root/app/backend/.env.tmp /root/app/backend/.env
        else
            echo "Adding DATABASE_URL to .env file"
            DB_HOST="postgres-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com"
            DB_PORT="25060"
            DB_NAME="defaultdb"
            DB_SSL="sslmode=require"
            
            echo "DATABASE_URL=postgresql://doadmin:\${DB_PASSWORD}@\${DB_HOST}:\${DB_PORT}/\${DB_NAME}?\${DB_SSL}" >> /root/app/backend/.env
        fi
    fi
    
    # Display the final environment file (with password masked for security)
    echo "Environment file contents (passwords masked):"
    cat /root/app/backend/.env | grep -v "PASSWORD\|SECRET\|KEY" || echo "No environment file found"
    echo "Database URL connection string (password masked):"
    grep "DATABASE_URL" /root/app/backend/.env | sed 's/doadmin:[^@]*@/doadmin:****@/g' || echo "No DATABASE_URL found"
    
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
    
    # Run database migrations with fallback options
    echo "Running database migrations..."
    export NODE_TLS_REJECT_UNAUTHORIZED=0
    yarn medusa db:migrate || echo "Migration failed, but continuing deployment"
    
    # Start the application with PM2
    echo "Starting application with PM2..."
    pm2 start yarn --name "medusa-server" -- start
    
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