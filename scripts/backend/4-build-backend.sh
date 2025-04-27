#!/bin/bash
set -e  # Exit immediately if a command fails

# Default parameters
SERVER_IP=${1}
SSH_USER=${2:-root}
SSH_KEY_PATH=${3:-~/.ssh/flowdose-do}
ENVIRONMENT=${4:-staging}
APP_DIR=${5:-/root/app}

# Validate parameters
if [ -z "$SERVER_IP" ]; then
  echo "ERROR: Server IP address is required"
  echo "Usage: $0 <server_ip> [ssh_user] [ssh_key_path] [environment] [app_dir]"
  exit 1
fi

echo "==================================================="
echo "Building and installing backend"
echo "==================================================="
echo "Server IP: $SERVER_IP"
echo "SSH User: $SSH_USER"
echo "Environment: $ENVIRONMENT"
echo "App Directory: $APP_DIR"

# Execute the build commands on the remote server
echo "Starting build process..."
BUILD_RESULT=$(ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$SSH_USER@$SERVER_IP" <<EOF
# Set variables
ENVIRONMENT="$ENVIRONMENT"
APP_DIR="$APP_DIR"
NODE_ENV="$ENVIRONMENT"
export NODE_ENV

cd \${APP_DIR}/backend || exit 1
echo "Current directory: \$(pwd)"

# Verify .env file exists
if [ ! -f ".env" ]; then
  echo "ERROR: .env file not found in backend directory"
  exit 1
fi

# Set Node.js memory limit for the build
export NODE_OPTIONS="--max-old-space-size=8192"

# Enable Corepack for Yarn version management
echo "Setting up Corepack for Yarn version management..."
corepack enable
corepack prepare yarn@4.4.0 --activate

# Install dependencies
echo "Installing dependencies..."
yarn install
if [ \$? -ne 0 ]; then
  echo "ERROR: Failed to install dependencies"
  exit 1
fi

# Show installed packages
echo "Yarn version: \$(yarn -v)"
echo "Node version: \$(node -v)"

# Build the application
echo "Building application..."
yarn build
if [ \$? -ne 0 ]; then
  echo "ERROR: Build failed"
  exit 1
fi

# Verify build output directory exists
if [ ! -d ".medusa/server" ]; then
  echo "ERROR: Build directory .medusa/server not found"
  exit 1
fi

# Ensure the environment file is copied to the server directory
echo "Copying environment file to server directory..."
cp .env .medusa/server/.env
cp .env .medusa/server/.env.\$ENVIRONMENT

# Install dependencies in the build directory
echo "Installing dependencies in the build directory..."
cd .medusa/server
yarn install
if [ \$? -ne 0 ]; then
  echo "ERROR: Failed to install dependencies in the build directory"
  exit 1
fi

# Run migrations
echo "Running database migrations..."
NODE_TLS_REJECT_UNAUTHORIZED=0 yarn medusa migrations run
if [ \$? -ne 0 ]; then
  echo "WARNING: Migration failed, continuing anyway"
fi

echo "Build and installation completed successfully."
exit 0
EOF
)

# Check the exit status of the SSH command
if [ $? -eq 0 ]; then
  echo -e "$BUILD_RESULT"
  echo -e "\nBuild and installation completed successfully."
else
  echo -e "$BUILD_RESULT"
  echo -e "\nBuild and installation failed."
  exit 1
fi

echo "==================================================="
echo "Backend build completed!"
echo "===================================================" 