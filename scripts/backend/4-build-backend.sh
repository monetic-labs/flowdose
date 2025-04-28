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
set -x # Enable debugging for remote commands
cd "${APP_DIR}/backend"

echo "Running yarn install..."
yarn install --frozen-lockfile || yarn install --check-files # Added fallback

echo "Running medusa build..."
export NODE_ENV="$ENVIRONMENT"
# Use npx to ensure local medusa CLI is used
npx medusa build --verbose

# === ADDED STEPS START ===
echo "Installing dependencies in build directory..."
cd "${APP_DIR}/backend/.medusa/server"
yarn install --production --check-files || yarn install --production # Added fallback and --production flag
cd "${APP_DIR}/backend" # Go back to original directory
# === ADDED STEPS END ===

# Copy .env file to build output directory
echo "Copying .env to build directory..."
if [ -f "${APP_DIR}/backend/.env" ]; then
  if [ -d "${APP_DIR}/backend/.medusa/server" ]; then
    cp "${APP_DIR}/backend/.env" "${APP_DIR}/backend/.medusa/server/.env"
    echo ".env file copied successfully."
  else
    echo "ERROR: Build output directory .medusa/server not found after build."
    exit 1
  fi
else
  echo "ERROR: Source .env file not found in ${APP_DIR}/backend/.env"
  exit 1
fi

echo "Build process completed."
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