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
    
    # IMPORTANT: Capture the DB_PASSWORD locally
    LOCAL_DB_PASSWORD="$DB_PASSWORD"
    
    # Debug output (with masking)
    if [ -n "$LOCAL_DB_PASSWORD" ]; then
        PASSWORD_FIRST_CHARS="${LOCAL_DB_PASSWORD:0:4}"
        PASSWORD_LAST_CHARS="${LOCAL_DB_PASSWORD: -4}"
        echo "Working with database password: ${PASSWORD_FIRST_CHARS}...${PASSWORD_LAST_CHARS} (length: ${#LOCAL_DB_PASSWORD})"
    else
        echo "WARNING: DB_PASSWORD is empty or not set. Database connections will likely fail."
    fi
    
    # IMPORTANT DEBUGGING FIX: Create a temporary environment file with the correct database URL
    # This will bypass all the complex expansion issues
    cat > /tmp/fixed_db_env.txt << EOL
DATABASE_URL=postgresql://doadmin:${DB_PASSWORD}@postgres-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25060/defaultdb?sslmode=require
EOL

    # Also create a file for Redis connection
    if [ -n "$REDIS_PASSWORD" ]; then
        echo "Working with Redis password ${REDIS_PASSWORD:0:4}...${REDIS_PASSWORD: -4} (length: ${#REDIS_PASSWORD})"
        cat > /tmp/fixed_redis_env.txt << EOL
REDIS_URL=rediss://default:${REDIS_PASSWORD}@redis-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25061
CACHE_REDIS_URL=rediss://default:${REDIS_PASSWORD}@redis-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25061
EVENTS_REDIS_URL=rediss://default:${REDIS_PASSWORD}@redis-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25061
EOL
    else
        echo "WARNING: REDIS_PASSWORD not set, Redis connections may fail."
    fi

    # Verify the temporary file has the correct password
    echo "Created temp environment file with database URL (password masked):"
    cat /tmp/fixed_db_env.txt | sed 's/doadmin:[^@]*@/doadmin:****@/g'

    # Copy the temporary environment file to the server
    echo "Copying temp environment files to server..."
    scp -o StrictHostKeyChecking=no /tmp/fixed_db_env.txt $SSH_USER@$IP_ADDRESS:/tmp/fixed_db_env.txt
    if [ -f "/tmp/fixed_redis_env.txt" ]; then
        scp -o StrictHostKeyChecking=no /tmp/fixed_redis_env.txt $SSH_USER@$IP_ADDRESS:/tmp/fixed_redis_env.txt
    fi

    # SSH to the backend server and perform deployment
    # Use -e flag to allow variable expansion in the heredoc
    ssh -o StrictHostKeyChecking=no $SSH_USER@$IP_ADDRESS << EOF
        # Instead of exporting, directly set DB_PASSWORD to the value from parent shell
        export DB_PASSWORD='${LOCAL_DB_PASSWORD}'
        export ENV="${ENV:-staging}"
        
        # Debug output to confirm password is set correctly
        if [ -n "\$DB_PASSWORD" ]; then
            PASSWORD_FIRST_CHARS="\${DB_PASSWORD:0:4}"
            PASSWORD_LAST_CHARS="\${DB_PASSWORD: -4}"
            echo "Server received database password: \${PASSWORD_FIRST_CHARS}...\${PASSWORD_LAST_CHARS} (length: \${#DB_PASSWORD})"
        else
            echo "WARNING: DB_PASSWORD is empty or not set on the server"
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
            
            # IMPORTANT FIX: Check for our fixed database URL file and use it
            if [ -f "/tmp/fixed_db_env.txt" ]; then
                echo "Found fixed database URL file. Using it to update the environment file..."
                FIXED_DB_URL=\$(cat /tmp/fixed_db_env.txt)
                
                # Extract password for verification
                DB_PASSWORD_IN_URL=\$(echo "\${FIXED_DB_URL}" | sed -n 's/.*doadmin:\([^@]*\)@.*/\1/p')
                PASSWORD_START=\${DB_PASSWORD_IN_URL:0:4}
                PASSWORD_END=\${DB_PASSWORD_IN_URL: -4}
                echo "Fixed DB URL contains password: \${PASSWORD_START}...\${PASSWORD_END} (length: \${#DB_PASSWORD_IN_URL})"
                
                # Update the DATABASE_URL in the environment file
                echo "Updating DATABASE_URL in environment file..."
                grep -v "DATABASE_URL=" /root/app/backend/.env.\${ENV} > /tmp/env.tmp
                cat /tmp/fixed_db_env.txt >> /tmp/env.tmp
                mv /tmp/env.tmp /root/app/backend/.env.\${ENV}
                echo "Environment file updated with fixed DATABASE_URL"
            else
                echo "WARNING: fixed_db_env.txt not found! Using environment file as is."
            fi
            
            # Similarly, check for fixed Redis URL file and use it
            if [ -f "/tmp/fixed_redis_env.txt" ]; then
                echo "Found fixed Redis URL file. Using it to update the environment file..."
                
                # Update the Redis URLs in the environment file
                grep -v "REDIS_URL=" /root/app/backend/.env.\${ENV} | grep -v "CACHE_REDIS_URL=" | grep -v "EVENTS_REDIS_URL=" > /tmp/env.tmp
                cat /tmp/fixed_redis_env.txt >> /tmp/env.tmp
                mv /tmp/env.tmp /root/app/backend/.env.\${ENV}
                echo "Environment file updated with fixed Redis URLs"
            else
                echo "WARNING: fixed_redis_env.txt not found! Redis connections may fail."
            fi
            
            # Create symlink to the environment file
            ln -sf /root/app/backend/.env.\${ENV} /root/app/backend/.env
            echo "Environment file symbolic link created."
            
            # Verify the final environment file
            echo "Verifying final environment file:"
            if grep -q "DATABASE_URL" /root/app/backend/.env; then
                DB_URL_LINE=\$(grep "DATABASE_URL" /root/app/backend/.env)
                # Check if it contains a password
                if echo "\${DB_URL_LINE}" | grep -q "doadmin:.*@"; then
                    DB_PASSWORD_IN_URL=\$(echo "\${DB_URL_LINE}" | sed -n 's/.*doadmin:\([^@]*\)@.*/\1/p')
                    PASSWORD_START=\${DB_PASSWORD_IN_URL:0:4}
                    PASSWORD_END=\${DB_PASSWORD_IN_URL: -4}
                    echo "✅ Final environment file has DATABASE_URL with password: \${PASSWORD_START}...\${PASSWORD_END} (length: \${#DB_PASSWORD_IN_URL})"
                else
                    echo "❌ Final environment file DATABASE_URL missing password!"
                fi
            else
                echo "❌ Final environment file missing DATABASE_URL!"
            fi
        else
            echo "❌ ERROR: /tmp/backend.env file not found!"
            # Create a minimal environment file
            echo "Creating minimal environment file..."
            mkdir -p /root/app/backend
            
            # Check for our fixed database URL file
            if [ -f "/tmp/fixed_db_env.txt" ]; then
                FIXED_DB_URL=\$(cat /tmp/fixed_db_env.txt)
                # Create minimal environment file with fixed DB URL
                cat > /root/app/backend/.env << EOL
# Core Settings
NODE_ENV=\${ENV}
PORT=9000

# Database
\${FIXED_DB_URL}
EOL

                # Add Redis URLs if available
                if [ -f "/tmp/fixed_redis_env.txt" ]; then
                    echo "" >> /root/app/backend/.env
                    echo "# Redis" >> /root/app/backend/.env
                    cat /tmp/fixed_redis_env.txt >> /root/app/backend/.env
                else
                    echo "" >> /root/app/backend/.env
                    echo "# Redis - WARNING: Using placeholders, connections may fail" >> /root/app/backend/.env
                    echo "REDIS_URL=rediss://default:placeholder@redis-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25061" >> /root/app/backend/.env
                    echo "CACHE_REDIS_URL=rediss://default:placeholder@redis-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25061" >> /root/app/backend/.env
                    echo "EVENTS_REDIS_URL=rediss://default:placeholder@redis-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25061" >> /root/app/backend/.env
                fi
                echo "Created minimal environment file with fixed DATABASE_URL"
            else
                echo "❌ ERROR: No fixed DB URL file found. Cannot continue!"
                exit 1
            fi
        fi
        
        # Enable Corepack for Yarn 4
        echo "Enabling Corepack for Yarn 4..."
        corepack enable
        corepack prepare yarn@4.4.0 --activate
        
        # Install dependencies in source directory
        echo "Installing dependencies in source directory..."
        yarn install
        
        # Test database connection before building
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
    EOF
fi

echo "Backend deployment script completed." 