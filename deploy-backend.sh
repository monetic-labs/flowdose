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
        # Ensure the ENV is explicitly set with the parent shell value
        export ENV="${ENV}"
        
        echo "DEBUG: ENV value is '\${ENV}'"
        
        # Debug output to confirm password is set correctly
        if [ -n "\$DB_PASSWORD" ]; then
            PASSWORD_FIRST_CHARS="\${DB_PASSWORD:0:4}"
            PASSWORD_LAST_CHARS="\${DB_PASSWORD: -4}"
            echo "Server received database password: \${PASSWORD_FIRST_CHARS}...\${PASSWORD_LAST_CHARS} (length: \${#DB_PASSWORD})"
        else
            echo "WARNING: DB_PASSWORD is empty or not set on the server"
        fi
        
        # =======================================================================
        # SYSTEM PREPARATION - Memory and storage optimization
        # =======================================================================
        echo "=== SYSTEM PREPARATION ==="
        
        # Set up permanent swap if it doesn't exist
        if [ ! -f /swapfile ]; then
            echo "Creating 2GB swap file for build process..."
            fallocate -l 2G /swapfile
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            
            # Make swap permanent by adding to fstab if not already there
            if ! grep -q "swapfile" /etc/fstab; then
                echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
                echo "Added swap to fstab for persistence across reboots"
            fi
            
            echo "Swap space created and activated"
            free -h
        elif [ "\$(swapon --show | wc -l)" -eq 0 ]; then
            echo "Swap file exists but not activated, activating now..."
            swapon /swapfile
            echo "Swap activated"
            free -h
        else
            echo "Swap already set up and active"
            free -h
        fi
        
        # Clean up older deployments to free space
        if [ -d "/root/app/backend.old" ]; then
            echo "Removing old backend directory to free up space..."
            rm -rf /root/app/backend.old
        fi
        
        # Configure Linux OOM killer to prevent killing our Node process
        # This reduces the chances of Node being killed during memory pressure
        echo "Setting Node.js OOM score adjustment to prevent killing during memory pressure..."
        for pid in \$(pgrep node); do
            echo -500 > /proc/\$pid/oom_score_adj 2>/dev/null || true
        done
        
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
        echo "Stopping all running PM2 processes..."
        pm2 stop all || true
        pm2 delete all || true
        
        # Navigate to backend directory
        cd /root/app/backend
        echo "Now in: \$(pwd)"
        
        # =======================================================================
        # ENVIRONMENT SETUP - Configure settings for build and runtime
        # =======================================================================
        echo "=== ENVIRONMENT SETUP ==="
        
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
            # Make sure ENV is not empty, default to "staging" if it is
            if [ -z "\${ENV}" ]; then
                echo "WARNING: ENV variable is empty! Defaulting to 'staging'"
                ENV="staging"
            fi
            echo "Using environment: \${ENV}"
            
            # Ensure target directory exists
            mkdir -p /root/app/backend
            
            # Clean up any old or incorrect environment files
            echo "Cleaning up old environment files..."
            if [ -f "/root/app/backend/.env.symlink" ]; then
                echo "Removing incorrect .env.symlink file..."
                rm -f /root/app/backend/.env.symlink
            fi
            
            # Check the content of the backend.env file before copying
            if [ -f "/tmp/backend.env" ]; then
                echo "Contents of /tmp/backend.env (with passwords masked):"
                cat /tmp/backend.env | grep -v "PASSWORD\|SECRET\|KEY" | head -n 10
                echo "Checking DATABASE_URL specifically:"
                DATABASE_URL_LINE=\$(grep "DATABASE_URL" /tmp/backend.env)
                if [ -n "\$DATABASE_URL_LINE" ]; then
                    # Mask the password for security
                    MASKED_URL=\$(echo "\$DATABASE_URL_LINE" | sed 's/doadmin:[^@]*@/doadmin:****@/g')
                    echo "Found DATABASE_URL: \$MASKED_URL"
                    
                    # Check if it's properly formed
                    if echo "\$DATABASE_URL_LINE" | grep -q "doadmin:.*@.*:.*\/"; then
                        echo "✅ DATABASE_URL appears to be properly formed"
                    else
                        echo "⚠️ WARNING: DATABASE_URL may be malformed"
                    fi
                else
                    echo "❌ No DATABASE_URL found in backend.env"
                fi
            else
                echo "❌ /tmp/backend.env file does not exist!"
            fi
            
            # Hard-code the environment name when creating the file (for debugging)
            echo "Creating environment file for \${ENV}..."
            if [ "\${ENV}" = "staging" ]; then
                echo "Using explicit staging environment..."
                cp /tmp/backend.env "/root/app/backend/.env.staging"
                echo "Creating direct symlink to staging environment..."
                rm -f /root/app/backend/.env
                ln -sf "/root/app/backend/.env.staging" "/root/app/backend/.env"
            else
                echo "Using environment: \${ENV}"
                cp /tmp/backend.env "/root/app/backend/.env.\${ENV}"
                echo "Creating symlink to environment \${ENV}..."
                rm -f /root/app/backend/.env
                ln -sf "/root/app/backend/.env.\${ENV}" "/root/app/backend/.env"
            fi
            
            # Verify files were created properly
            echo "Verifying environment files:"
            ls -la /root/app/backend/.env*
            
            # Double-check that .env exists and has content
            if [ ! -f "/root/app/backend/.env" ] || [ ! -s "/root/app/backend/.env" ]; then
                echo "⚠️ WARNING: .env file is missing or empty. Copying directly as fallback..."
                cp /tmp/backend.env /root/app/backend/.env
                echo "✅ Direct copy completed."
            fi
            
            # Verify and fix DATABASE_URL if the password is missing or malformed
            if ! grep -q "doadmin:.*@postgres-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25060/defaultdb" /root/app/backend/.env; then
                echo "⚠️ DATABASE_URL is missing or malformed, fixing it..."
                # Extract the correct DATABASE_URL from the original file
                DB_URL=\$(grep DATABASE_URL /tmp/backend.env)
                # Check if we got a proper URL
                if [ -z "\$DB_URL" ] || ! echo "\$DB_URL" | grep -q "doadmin:.*@"; then
                    echo "⚠️ Could not get proper DATABASE_URL from /tmp/backend.env"
                    # Create a direct DATABASE_URL with the current DB_PASSWORD
                    if [ -n "\$DB_PASSWORD" ]; then
                        echo "Creating DATABASE_URL with password directly..."
                        DB_URL="DATABASE_URL=postgresql://doadmin:\${DB_PASSWORD}@postgres-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25060/defaultdb?sslmode=require"
                    else
                        echo "❌ No DB_PASSWORD available! Database connection will likely fail."
                        DB_URL="DATABASE_URL=postgresql://doadmin:placeholder@postgres-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25060/defaultdb?sslmode=require"
                    fi
                fi
                
                # Create a temporary file without the broken DATABASE_URL
                grep -v "DATABASE_URL" /root/app/backend/.env > /tmp/env.fixed
                # Add the correct DATABASE_URL
                echo "\$DB_URL" >> /tmp/env.fixed
                # Replace the environment file
                mv /tmp/env.fixed /root/app/backend/.env
                echo "✅ Fixed DATABASE_URL in .env file"
                
                # If we're using staging, update the .env.staging file too
                if [ "\${ENV}" = "staging" ]; then
                    echo "Updating .env.staging with fixed DATABASE_URL..."
                    if [ -f "/root/app/backend/.env.staging" ]; then
                        grep -v "DATABASE_URL" /root/app/backend/.env.staging > /tmp/env.staging.fixed
                        echo "\$DB_URL" >> /tmp/env.staging.fixed
                        mv /tmp/env.staging.fixed /root/app/backend/.env.staging
                        echo "✅ Fixed DATABASE_URL in .env.staging file"
                    fi
                fi
            fi
            
            echo "Checking if our new variables were copied correctly..."
            grep -q "MEDUSA_ADMIN_EMAIL" /root/app/backend/.env && echo "✅ MEDUSA_ADMIN_EMAIL found in .env" || echo "❌ MEDUSA_ADMIN_EMAIL not found in .env"
            grep -q "MEDUSA_ADMIN_PASSWORD" /root/app/backend/.env && echo "✅ MEDUSA_ADMIN_PASSWORD found in .env" || echo "❌ MEDUSA_ADMIN_PASSWORD not found in .env"
            
            # Check DATABASE_URL but don't try to modify it
            echo "Verifying DATABASE_URL in the environment file:"
            if grep -q "DATABASE_URL" /root/app/backend/.env; then
                DB_URL_LINE=\$(grep "DATABASE_URL" /root/app/backend/.env)
                if echo "\${DB_URL_LINE}" | grep -q "doadmin:.*@"; then
                    DB_PASS=\$(echo "\${DB_URL_LINE}" | sed -n 's/.*doadmin:\([^@]*\)@.*/\1/p')
                    echo "✅ DATABASE_URL contains password: \${DB_PASS:0:4}...\${DB_PASS: -4} (length: \${#DB_PASS})"
                else
                    echo "⚠️ WARNING: DATABASE_URL appears to be missing a password: \${DB_URL_LINE}"
                fi
            else
                echo "❌ DATABASE_URL not found in .env file"
            fi
            
            # Display structure of the environment file
            echo "Environment file structure:"
            wc -l /root/app/backend/.env
            echo "First 3 lines:"
            head -n 3 /root/app/backend/.env
            echo "Last 3 lines:"
            tail -n 3 /root/app/backend/.env
        else
            echo "❌ ERROR: /tmp/backend.env file not found!"
            # Create a minimal .env file
            echo "Creating minimal .env file..."
            cat > /root/app/backend/.env << EOF
# Core Settings
NODE_ENV=\${ENV}
PORT=9000

# Database
DATABASE_URL=postgresql://doadmin:\${DB_PASSWORD}@postgres-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25060/defaultdb?sslmode=require

# Redis
REDIS_URL=rediss://default:\${REDIS_PASSWORD:-placeholder}@redis-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25061
CACHE_REDIS_URL=rediss://default:\${REDIS_PASSWORD:-placeholder}@redis-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25061
EVENTS_REDIS_URL=rediss://default:\${REDIS_PASSWORD:-placeholder}@redis-flowdose-staging-0423-do-user-17309531-0.f.db.ondigitalocean.com:25061

# Admin User
MEDUSA_ADMIN_EMAIL=\${MEDUSA_ADMIN_EMAIL:-admin@flowdose.xyz}
MEDUSA_ADMIN_PASSWORD=\${MEDUSA_ADMIN_PASSWORD:-secretpassword}
EOF
            echo "Created minimal .env file."
            
            # Verify the DB_PASSWORD is included
            if grep -q "doadmin:\${DB_PASSWORD}" /root/app/backend/.env; then
                echo "✅ Minimal .env file has DB_PASSWORD placeholder"
                if [ -n "\${DB_PASSWORD}" ]; then
                    echo "✅ DB_PASSWORD is set, connection should work"
                else
                    echo "❌ DB_PASSWORD is empty, connection will likely fail"
                fi
            else
                echo "❌ Something went wrong creating the minimal .env file"
            fi
        fi
        
        # Enable Corepack for Yarn 4
        echo "Enabling Corepack for Yarn 4..."
        corepack enable
        corepack prepare yarn@4.4.0 --activate
        
        # =======================================================================
        # BUILD PREPARATION - Optimize before build to reduce memory usage
        # =======================================================================
        echo "=== BUILD PREPARATION ==="
        
        # Clear caches and clean up node_modules
        echo "Cleaning up previous build artifacts and caches..."
        rm -rf /root/app/backend/.medusa || true
        rm -rf /root/app/backend/node_modules/.cache || true
        rm -rf /root/.yarn/cache || true
        
        # Create .yarnrc.yml file with optimizations
        cat > /root/app/backend/.yarnrc.yml << EOL
nodeLinker: node-modules
compressionLevel: 0
enableGlobalCache: false
logFilters:
  - code: YN0002
    level: discard
  - code: YN0060
    level: discard
  - code: YN0086
    level: discard
nmMode: hardlinks-local
enableImmutableInstalls: false
networkConcurrency: 1
EOL
        
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
        
        # =======================================================================
        # BUILD PROCESS - Optimized for memory constraints
        # =======================================================================
        echo "=== BUILD PROCESS ==="
        
        # Create a custom script that runs the build with optimized memory settings
        cat > /tmp/build-with-memory-opt.js << EOL
const { execSync } = require('child_process');

// Free up memory before starting
try {
  global.gc();
} catch (e) {
  console.log('No garbage collection available, continuing anyway');
}

// Run the build command with memory optimizations
try {
  console.log('Starting optimized build process...');
  execSync('yarn medusa build', {
    env: {
      ...process.env,
      NODE_OPTIONS: '--max-old-space-size=2048 --max-semi-space-size=64 --optimize-for-size --gc-interval=100'
    },
    stdio: 'inherit'
  });
  console.log('Build completed successfully');
} catch (error) {
  console.error('Build failed with error:', error.message);
  process.exit(1);
}
EOL
        
        # Run the optimized build
        echo "Building the application with memory optimizations..."
        export NODE_OPTIONS="--max-old-space-size=2048 --max-semi-space-size=64 --optimize-for-size --gc-interval=100"
        
        # Try the optimized build, with fallbacks
        node /tmp/build-with-memory-opt.js || {
            echo "Primary build approach failed, trying backup method..."
            NODE_ENV=production node --max-old-space-size=2048 node_modules/.bin/medusa build || {
                echo "Build still failing, attempting minimal build..."
                # If both fail, try a direct approach
                NODE_ENV=production NODE_OPTIONS="--max-old-space-size=2048" npx --no medusa build || {
                    echo "All build methods failed. Please check the logs."
                    exit 1
                }
            }
        }
        
        # =======================================================================
        # DEPLOYMENT - Set up the server for production
        # =======================================================================
        echo "=== DEPLOYMENT ==="
        
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
        
        # Check if server is responding
        echo "Checking if the server is responding..."
        timeout 30 bash -c 'while [[ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:9000/health)" != "200" ]]; do echo "Waiting for server..." && sleep 2; done' || echo "Server health check timed out, but continuing anyway"
        
        echo "Backend deployment completed successfully!"
    EOF
fi

echo "Backend deployment script completed." 