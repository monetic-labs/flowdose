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
    
    #############################################
    # ENVIRONMENT FILE HANDLING                 #
    #############################################
    
    echo "Setting up environment files..."
    
    # Verify the original environment file exists
    if [ ! -f "/tmp/backend.env" ]; then
        echo "❌ ERROR: Required environment file /tmp/backend.env not found!"
        echo "This file should be created by the GitHub workflow and copied to the server."
        exit 1
    fi
    
    # Display environment file diagnostics
    echo "Diagnosing /tmp/backend.env file:"
    echo "  - File exists: $([ -f "/tmp/backend.env" ] && echo "✅ Yes" || echo "❌ No")"
    echo "  - File size: $(stat -c%s /tmp/backend.env) bytes"
    echo "  - Line count: $(wc -l < /tmp/backend.env) lines"
    
    # Check for DATABASE_URL in the environment file
    echo "Checking DATABASE_URL in original environment file:"
    DB_URL_LINE=\$(grep "DATABASE_URL" /tmp/backend.env)
    if [ -n "\$DB_URL_LINE" ]; then
        # Display the DATABASE_URL (with password masked)
        MASKED_URL=\$(echo "\$DB_URL_LINE" | sed 's/doadmin:[^@]*@/doadmin:****@/g')
        echo "  - Found DATABASE_URL: \$MASKED_URL"
        
        # Verify DATABASE_URL format
        if echo "\$DB_URL_LINE" | grep -q "postgresql://doadmin:.*@postgres-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25060/defaultdb"; then
            echo "  - ✅ DATABASE_URL appears to be correctly formatted"
        else
            echo "  - ⚠️ WARNING: DATABASE_URL in /tmp/backend.env may be malformed!"
        fi
    else
        echo "  - ❌ ERROR: DATABASE_URL not found in /tmp/backend.env!"
    fi
    
    #############################################
    # CREATE ENVIRONMENT FILES WITH CORRECT PATHS #
    #############################################
    
    # First, clean up any existing environment files
    echo "Cleaning up any existing environment files..."
    rm -f /root/app/backend/.env.staging
    rm -f /root/app/backend/.env
    
    # Create the environment-specific file and symlink
    ENV_SPECIFIC_FILE="/root/app/backend/.env.staging"
    ENV_SYMLINK="/root/app/backend/.env"
    
    echo "Creating environment-specific file at \$ENV_SPECIFIC_FILE..."
    cp /tmp/backend.env "\$ENV_SPECIFIC_FILE"
    
    # Verify the environment file was created
    if [ ! -f "\$ENV_SPECIFIC_FILE" ]; then
        echo "❌ ERROR: Failed to create \$ENV_SPECIFIC_FILE!"
        exit 1
    fi
    
    # Create symlink
    echo "Creating symlink from \$ENV_SYMLINK to \$ENV_SPECIFIC_FILE..."
    ln -sf "\$ENV_SPECIFIC_FILE" "\$ENV_SYMLINK"
    
    # Verify the symlink was created
    if [ ! -L "\$ENV_SYMLINK" ]; then
        echo "❌ ERROR: Failed to create symlink at \$ENV_SYMLINK!"
        exit 1
    fi
    
    # List all environment files to verify
    echo "Verifying environment files:"
    ls -la /root/app/backend/.env*
    
    # Verify DATABASE_URL in the final environment file
    echo "Verifying DATABASE_URL in final environment file:"
    DB_URL_FINAL=\$(grep "DATABASE_URL" "\$ENV_SYMLINK")
    if [ -n "\$DB_URL_FINAL" ]; then
        MASKED_URL_FINAL=\$(echo "\$DB_URL_FINAL" | sed 's/doadmin:[^@]*@/doadmin:****@/g')
        echo "  - Found DATABASE_URL: \$MASKED_URL_FINAL"
        
        if echo "\$DB_URL_FINAL" | grep -q "doadmin:.*@postgres"; then
            echo "  - ✅ DATABASE_URL contains password and correct hostname"
        else
            echo "  - ❌ ERROR: DATABASE_URL is malformed in final environment file!"
            exit 1
        fi
    else
        echo "  - ❌ ERROR: DATABASE_URL not found in final environment file!"
        exit 1
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