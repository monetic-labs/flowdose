#!/bin/bash
set -e  # Exit immediately if a command fails

# Default parameters
SERVER_IP=${1}
SSH_USER=${2:-root}
SSH_KEY_PATH=${3:-~/.ssh/flowdose-do}
BRANCH=${4:-main}
APP_DIR=${5:-/root/app}

# Validate parameters
if [ -z "$SERVER_IP" ]; then
  echo "ERROR: Server IP address is required"
  echo "Usage: $0 <server_ip> [ssh_user] [ssh_key_path] [branch] [app_dir]"
  exit 1
fi

echo "==================================================="
echo "Cloning repository for backend deployment"
echo "==================================================="
echo "Server IP: $SERVER_IP"
echo "SSH User: $SSH_USER"
echo "SSH Key: $SSH_KEY_PATH"
echo "Branch: $BRANCH"
echo "App Directory: $APP_DIR"

# Execute the clone commands on the remote server
echo "Starting repository setup..."
CLONE_RESULT=$(ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$SSH_USER@$SERVER_IP" <<EOF
# Set variables
BRANCH="$BRANCH"
APP_DIR="$APP_DIR"

# First, remove any old backup directory
echo "Removing old backup directory if it exists..."
rm -rf \${APP_DIR}/backend.old

# Then backup the current directory if it exists
if [ -d "\${APP_DIR}/backend" ]; then
  echo "Backing up existing backend directory..."
  mv \${APP_DIR}/backend \${APP_DIR}/backend.old
fi

# Create app directory if it doesn't exist
mkdir -p \${APP_DIR}
cd \${APP_DIR}

# Clone the repository
echo "Cloning repository (branch: \${BRANCH})..."
git clone --depth 1 -b \${BRANCH} https://github.com/monetic-labs/flowdose.git \${APP_DIR}/temp-repo

# Check if clone was successful
if [ ! -d "\${APP_DIR}/temp-repo" ]; then
  echo "ERROR: Clone failed - temp directory doesn't exist"
  exit 1
fi

# List the cloned directory contents
echo "Clone successful. Directory contents:"
ls -la \${APP_DIR}/temp-repo

# Check if backend directory exists in the repo
if [ ! -d "\${APP_DIR}/temp-repo/backend" ]; then
  echo "ERROR: Backend directory not found in cloned repository"
  # Restore backup if it exists
  if [ -d "\${APP_DIR}/backend.old" ]; then
    echo "Restoring backup..."
    mv \${APP_DIR}/backend.old \${APP_DIR}/backend
  fi
  exit 1
fi

echo "Backend directory found. Contents:"
ls -la \${APP_DIR}/temp-repo/backend

# Move backend directory to final location
echo "Moving backend directory to final location..."
mv \${APP_DIR}/temp-repo/backend \${APP_DIR}/

# Verify package.json exists
if [ ! -f "\${APP_DIR}/backend/package.json" ]; then
  echo "ERROR: package.json not found in backend directory"
  # Restore backup if it exists
  if [ -d "\${APP_DIR}/backend.old" ]; then
    echo "Restoring backup..."
    mv \${APP_DIR}/backend.old \${APP_DIR}/backend
  fi
  exit 1
fi

echo "Verified package.json exists. Backend repository setup successful."

# Clean up temporary repository
echo "Cleaning up temporary repository..."
rm -rf \${APP_DIR}/temp-repo

# Remove backup if everything was successful
if [ -d "\${APP_DIR}/backend.old" ]; then
  echo "Removing old backup..."
  rm -rf \${APP_DIR}/backend.old
fi

echo "Repository setup completed successfully."
exit 0
EOF
)

# Check the exit status of the SSH command
if [ $? -eq 0 ]; then
  echo -e "$CLONE_RESULT"
  echo -e "\nRepository setup completed successfully."
else
  echo -e "$CLONE_RESULT"
  echo -e "\nRepository setup failed."
  exit 1
fi

echo "==================================================="
echo "Repository cloning completed!"
echo "===================================================" 