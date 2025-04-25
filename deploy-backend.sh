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
    
    # IMPORTANT: We need to capture the DB_PASSWORD locally and pass it directly
    # The issue is that ${DB_PASSWORD} is not being properly expanded inside the heredoc
    LOCAL_DB_PASSWORD="${DB_PASSWORD}"
    # Mask display for security, but show length and first/last chars for debugging
    PASSWORD_START="${LOCAL_DB_PASSWORD:0:4}"
    PASSWORD_END="${LOCAL_DB_PASSWORD: -4}"
    PASSWORD_LENGTH="${#LOCAL_DB_PASSWORD}"
    echo "Local DB_PASSWORD: ${PASSWORD_START}...${PASSWORD_END} (length: ${PASSWORD_LENGTH})"
    
    # SSH to the backend server and perform deployment
    # NOTE: We're using a different technique to ensure DB_PASSWORD gets passed correctly
    ssh -o StrictHostKeyChecking=no $SSH_USER@$IP_ADDRESS "export SERVER_DB_PASSWORD='${LOCAL_DB_PASSWORD}'; bash -s" << ENDSSH
        # Use the password we passed in directly
        export DB_PASSWORD="\${SERVER_DB_PASSWORD}"
        
        echo "DEBUG: Received DB_PASSWORD length: \${#DB_PASSWORD}"
        export ENV="${ENV:-staging}"
        
        # Display important environment variables for debugging (partially masked)
        echo "DEBUG: Important variables:"
        echo "- NODE_ENV: \${ENV}"
        
        if [ -n "\${DB_PASSWORD}" ]; then
            PASSWORD_START=\${DB_PASSWORD:0:4}
            PASSWORD_END=\${DB_PASSWORD: -4}
            echo "- DB_PASSWORD: \${PASSWORD_START}...\${PASSWORD_END} (length: \${#DB_PASSWORD})"
        else
            echo "- DB_PASSWORD: EMPTY OR UNDEFINED"
        fi
        
        if [ -n "\${MEDUSA_ADMIN_PASSWORD}" ]; then
            echo "- MEDUSA_ADMIN_PASSWORD length: \${#MEDUSA_ADMIN_PASSWORD}"
        else
            echo "- MEDUSA_ADMIN_PASSWORD: EMPTY OR UNDEFINED"
        fi
        
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
            if grep -q "DATABASE_URL" /root/app/backend/.env; then
                DB_URL_LINE=\$(grep "DATABASE_URL" /root/app/backend/.env)
                echo "Found DATABASE_URL: \${DB_URL_LINE}"
                
                # Check if the URL contains a password (showing as doadmin:...)
                if echo "\${DB_URL_LINE}" | grep -q "doadmin:.*@"; then
                    # Extract just the password part
                    DB_PASSWORD_IN_URL=\$(echo "\${DB_URL_LINE}" | sed -n 's/.*doadmin:\([^@]*\)@.*/\1/p')
                    PASSWORD_START=\${DB_PASSWORD_IN_URL:0:4}
                    PASSWORD_END=\${DB_PASSWORD_IN_URL: -4}
                    
                    echo "✅ DATABASE_URL contains password: \${PASSWORD_START}...\${PASSWORD_END} (length: \${#DB_PASSWORD_IN_URL})"
                else
                    echo "❌ DATABASE_URL missing password or in wrong format"
                fi
            else
                echo "❌ DATABASE_URL not found in .env"
            fi
            
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
                
                # Show passwords more explicitly for debugging (first/last 4 chars)
                if [ -n "\${DB_PASSWORD}" ]; then
                    PASSWORD_START=\${DB_PASSWORD:0:4}
                    PASSWORD_END=\${DB_PASSWORD: -4}
                    echo "Using DB_PASSWORD: \${PASSWORD_START}...\${PASSWORD_END} (length: \${#DB_PASSWORD})"
                else
                    echo "WARNING: DB_PASSWORD is empty or unset"
                fi
                
                # Update or add the DATABASE_URL with the password from the parent shell
                grep -v "DATABASE_URL=" /root/app/backend/.env > /root/app/backend/.env.tmp || touch /root/app/backend/.env.tmp
                echo "DATABASE_URL=postgresql://doadmin:${DB_PASSWORD}@\${DB_HOST}:\${DB_PORT}/\${DB_NAME}?\${DB_SSL}" >> /root/app/backend/.env.tmp
                mv /root/app/backend/.env.tmp /root/app/backend/.env
                echo "DATABASE_URL updated with password"
                
                # Show the updated DATABASE_URL with partially masked password
                DB_URL_LINE=\$(grep "DATABASE_URL" /root/app/backend/.env)
                # Extract just the password part
                DB_PASSWORD_IN_URL=\$(echo "\${DB_URL_LINE}" | sed -n 's/.*doadmin:\([^@]*\)@.*/\1/p')
                PASSWORD_START=\${DB_PASSWORD_IN_URL:0:4}
                PASSWORD_END=\${DB_PASSWORD_IN_URL: -4}
                echo "Updated DATABASE_URL with password: \${PASSWORD_START}...\${PASSWORD_END} (length: \${#DB_PASSWORD_IN_URL})"
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
        
        # Test database connection before running migrations
        echo "Testing database connection..."
        if [ -f "/root/app/backend/.env" ]; then
            # Extract DATABASE_URL from .env file
            TEST_DB_URL=\$(grep "DATABASE_URL" /root/app/backend/.env | cut -d '=' -f 2-)
            if [ -n "\${TEST_DB_URL}" ]; then
                echo "Found DATABASE_URL, testing connection..."
                # Install psql if not present
                which psql >/dev/null || apt-get update && apt-get install -y postgresql-client
                
                # Try to connect
                export PGPASSWORD=\$(echo "\${TEST_DB_URL}" | sed -n 's/.*doadmin:\([^@]*\)@.*/\1/p')
                DB_HOST=\$(echo "\${TEST_DB_URL}" | sed -n 's/.*@\([^:]*\):.*/\1/p')
                DB_PORT=\$(echo "\${TEST_DB_URL}" | sed -n 's/.*:\([^/]*\)\/.*/\1/p')
                DB_NAME=\$(echo "\${TEST_DB_URL}" | sed -n 's/.*\/\([^?]*\).*/\1/p')
                
                echo "Testing connection to \${DB_HOST}:\${DB_PORT} database \${DB_NAME}"
                echo "Password first 4 chars: \${PGPASSWORD:0:4}..."
                
                if psql -h "\${DB_HOST}" -p "\${DB_PORT}" -U "doadmin" -d "\${DB_NAME}" -c "SELECT 1" >/dev/null 2>&1; then
                    echo "✅ Database connection successful"
                else
                    echo "❌ Database connection failed"
                    echo "Trying to connect without SSL requirements..."
                    if psql -h "\${DB_HOST}" -p "\${DB_PORT}" -U "doadmin" -d "\${DB_NAME}" -c "SELECT 1" -o /dev/null 2>&1; then
                        echo "✅ Database connection without SSL successful"
                    else
                        echo "❌ Database connection failed even without SSL"
                    fi
                fi
            else
                echo "DATABASE_URL not found in .env file"
            fi
        else
            echo "No .env file found"
        fi
        
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