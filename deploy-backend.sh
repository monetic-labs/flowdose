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
    echo "  - Navigate to /root/app/backend"
    echo "  - Pull latest code from the backend directory"
    echo "  - Enable Corepack for Yarn 4"
    echo "  - Install dependencies"
    echo "  - Build the application"
    echo "  - Copy environment to build directory"
    echo "  - Install dependencies in build directory"
    echo "  - Run database migrations"
    echo "  - Start the application with PM2 from the build directory"
    
    echo "Backend deployment simulation completed successfully!"
else
    echo "Deploying to $SSH_USER@$IP_ADDRESS..."
    
    # Check environment variables
    echo "Validating environment variables..."
    # Try to find and run the validation script
    if [ -f "./validate-backend-env.sh" ]; then
        ./validate-backend-env.sh $ENV
    elif [ -f "../scripts/validate-backend-env.sh" ]; then
        ../scripts/validate-backend-env.sh $ENV
    else
        echo "Skipping environment validation - script not found"
    fi
    
    # SSH to the backend server and perform deployment
    ssh -o StrictHostKeyChecking=no $SSH_USER@$IP_ADDRESS << ENDSSH
        # Export the password from parent shell
        export DB_PASSWORD="${DB_PASSWORD}"
        export ENV="${ENV:-staging}"
        
        # Check if directory exists, if not clone the repository
        if [ ! -d "/root/app/backend" ]; then
            echo "Backend directory doesn't exist, creating..."
            mkdir -p /root/app
            # Clone only the backend directory using sparse checkout
            git clone --no-checkout https://github.com/monetic-labs/flowdose.git /root/app/repo-temp
            cd /root/app/repo-temp
            git sparse-checkout init --cone
            git sparse-checkout set backend
            git checkout
            mv backend /root/app/
            cd /root/app
            rm -rf repo-temp
        fi
        
        # Stop any running PM2 processes
        pm2 stop all || true
        pm2 delete all || true
        
        # Navigate to backend directory
        cd /root/app/backend
        
        # Pull latest code
        if [ -d ".git" ]; then
            git pull
        else
            echo "Warning: Not a git repository. Cannot pull latest changes."
        fi
        
        # Copy over the environment file (this would be uploaded in a separate step)
        if [ -f "/tmp/backend.env" ]; then
            echo "Found /tmp/backend.env - showing first few lines (with passwords masked):"
            head -n 5 /tmp/backend.env | sed 's/\(PASSWORD=[^[:space:]]*\)/PASSWORD=******/g'
            
            echo "Copying environment file to backend directory..."
            cp /tmp/backend.env /root/app/backend/.env.\${ENV}
            ln -sf /root/app/backend/.env.\${ENV} /root/app/backend/.env
            echo "Environment file updated."
            
            echo "Checking if our new variables were copied correctly..."
            grep -q "MEDUSA_ADMIN_EMAIL" /root/app/backend/.env && echo "✅ MEDUSA_ADMIN_EMAIL found in .env" || echo "❌ MEDUSA_ADMIN_EMAIL not found in .env"
            grep -q "MEDUSA_ADMIN_PASSWORD" /root/app/backend/.env && echo "✅ MEDUSA_ADMIN_PASSWORD found in .env" || echo "❌ MEDUSA_ADMIN_PASSWORD not found in .env"
            
            echo "Checking DATABASE_URL in the .env file:"
            grep "DATABASE_URL" /root/app/backend/.env | sed 's/doadmin:[^@]*@/doadmin:****@/g' || echo "❌ DATABASE_URL not found in .env"
            
            echo "Checking line count and structure of .env file:"
            wc -l /root/app/backend/.env
            echo "First 3 lines:"
            head -n 3 /root/app/backend/.env
            echo "Last 3 lines:"
            tail -n 3 /root/app/backend/.env
            
            # Verify DATABASE_URL has the password
            if ! grep -q "doadmin:.*@" /root/app/backend/.env; then
                echo "DATABASE_URL not found or missing password, updating it..."
                DB_HOST="postgres-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com"
                DB_PORT="25060"
                DB_NAME="defaultdb"
                DB_SSL="sslmode=require"
                
                # Update or add the DATABASE_URL with the password from the parent shell
                grep -v "DATABASE_URL=" /root/app/backend/.env > /root/app/backend/.env.tmp || touch /root/app/backend/.env.tmp
                echo "DATABASE_URL=postgresql://doadmin:${DB_PASSWORD}@\${DB_HOST}:\${DB_PORT}/\${DB_NAME}?\${DB_SSL}" >> /root/app/backend/.env.tmp
                mv /root/app/backend/.env.tmp /root/app/backend/.env
                echo "DATABASE_URL updated with password"
                
                echo "Updated DATABASE_URL in the .env file:"
                grep "DATABASE_URL" /root/app/backend/.env | sed 's/doadmin:[^@]*@/doadmin:****@/g'
            fi
        else
            echo "❌ ERROR: /tmp/backend.env file not found!"
            # Create a minimal .env file
            echo "Creating minimal .env file..."
            cat > /root/app/backend/.env << EOF
# Core Settings
NODE_ENV=\${ENV}
PORT=9000

# Database
DATABASE_URL=postgresql://doadmin:${DB_PASSWORD}@postgres-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25060/defaultdb?sslmode=require

# Admin User
MEDUSA_ADMIN_EMAIL=${MEDUSA_ADMIN_EMAIL}
MEDUSA_ADMIN_PASSWORD=${MEDUSA_ADMIN_PASSWORD}
EOF
            echo "Created minimal .env file."
        fi
        
        # Enable Corepack for Yarn 4
        echo "Enabling Corepack for Yarn 4..."
        corepack enable
        corepack prepare yarn@4.4.0 --activate
        
        # Install dependencies in source directory
        echo "Installing dependencies in source directory..."
        yarn install
        
        # Build the application
        echo "Building the application..."
        yarn build
        
        # Copy environment to the build directory
        echo "Copying environment file to build directory..."
        cp /root/app/backend/.env /root/app/backend/.medusa/server/.env.production
        
        # Install dependencies in the build directory
        echo "Installing dependencies in build directory..."
        cd /root/app/backend/.medusa/server
        yarn install
        
        # Run database migrations
        echo "Running database migrations..."
        NODE_ENV=production yarn medusa migrations run
        
        # Start the application with PM2 from the build directory
        echo "Starting application with PM2 from build directory..."
        NODE_ENV=production pm2 start --name "medusa-server" yarn -- start
        NODE_ENV=production pm2 start --name "medusa-worker" yarn -- start --worker
        
        # Save the PM2 configuration
        pm2 save
        
        # Return to root directory
        cd /root/app/backend
        
        echo "Backend deployment completed successfully!"
    ENDSSH
fi

echo "Backend deployment script completed." 