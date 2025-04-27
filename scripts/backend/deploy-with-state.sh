#!/bin/bash
set -e  # Exit immediately if a command fails

# Default parameters
ENVIRONMENT=${1:-staging}
SSH_USER=${2:-root}
SSH_KEY_PATH=${3:-~/.ssh/flowdose-do}
BRANCH=${4:-main}
APP_DIR=${5:-/root/app}
SPACES_BUCKET=${6:-flowdose-state-storage}
SPACES_REGION=${7:-sfo3}
SPACES_ACCESS_KEY=${8}
SPACES_SECRET_KEY=${9}

# Validate parameters
if [ -z "$SPACES_ACCESS_KEY" ] || [ -z "$SPACES_SECRET_KEY" ]; then
  echo "ERROR: Spaces access key and secret key are required"
  echo "Usage: $0 [environment] [ssh_user] [ssh_key_path] [branch] [app_dir] [spaces_bucket] [spaces_region] <spaces_access_key> <spaces_secret_key>"
  exit 1
fi

# Define script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==================================================="
echo "Starting Backend Deployment Process with State File IP Retrieval"
echo "==================================================="
echo "Environment: $ENVIRONMENT"
echo "SSH User: $SSH_USER"
echo "Branch: $BRANCH"
echo "App Directory: $APP_DIR"
echo "Spaces Bucket: $SPACES_BUCKET"
echo "Spaces Region: $SPACES_REGION"
echo "Script Directory: $SCRIPT_DIR"

# Step 0: Get server IP from state file
echo -e "\n\n=== STEP 0: Retrieving Server IP from Terraform State ==="
IP_FILE="${SCRIPT_DIR}/server_ip_${ENVIRONMENT}.txt"
$SCRIPT_DIR/0-get-server-ip.sh "$ENVIRONMENT" "$SPACES_BUCKET" "$SPACES_REGION" "$SPACES_ACCESS_KEY" "$SPACES_SECRET_KEY" "$IP_FILE"
if [ $? -ne 0 ]; then
  echo "ERROR: Server IP retrieval failed"
  exit 1
fi

# Read the server IP from the file
SERVER_IP=$(cat "$IP_FILE")
if [ -z "$SERVER_IP" ]; then
  echo "ERROR: Failed to retrieve server IP from file"
  exit 1
fi

echo "Retrieved Server IP: $SERVER_IP"

# Step 1: Verify server
echo -e "\n\n=== STEP 1: Verifying Server Configuration ==="
$SCRIPT_DIR/1-verify-server.sh "$SERVER_IP" "$SSH_USER" "$SSH_KEY_PATH"
if [ $? -ne 0 ]; then
  echo "ERROR: Server verification failed"
  exit 1
fi

# Step 2: Clone repository
echo -e "\n\n=== STEP 2: Cloning Repository ==="
$SCRIPT_DIR/2-clone-repo.sh "$SERVER_IP" "$SSH_USER" "$SSH_KEY_PATH" "$BRANCH" "$APP_DIR"
if [ $? -ne 0 ]; then
  echo "ERROR: Repository cloning failed"
  exit 1
fi

# Step 3: Set up environment
echo -e "\n\n=== STEP 3: Setting Up Environment ==="
$SCRIPT_DIR/3-setup-env.sh "$SERVER_IP" "$SSH_USER" "$SSH_KEY_PATH" "$ENVIRONMENT" "$APP_DIR" "$SPACES_BUCKET" "$SPACES_REGION" "$SPACES_ACCESS_KEY" "$SPACES_SECRET_KEY"
if [ $? -ne 0 ]; then
  echo "ERROR: Environment setup failed"
  exit 1
fi

# Step 4: Build backend
echo -e "\n\n=== STEP 4: Building Backend ==="
$SCRIPT_DIR/4-build-backend.sh "$SERVER_IP" "$SSH_USER" "$SSH_KEY_PATH" "$ENVIRONMENT" "$APP_DIR"
if [ $? -ne 0 ]; then
  echo "ERROR: Backend build failed"
  exit 1
fi

# Step 5: Start server
echo -e "\n\n=== STEP 5: Starting Server ==="
$SCRIPT_DIR/5-start-server.sh "$SERVER_IP" "$SSH_USER" "$SSH_KEY_PATH" "$ENVIRONMENT" "$APP_DIR"
if [ $? -ne 0 ]; then
  echo "ERROR: Server start failed"
  exit 1
fi

# Clean up the IP file if desired
# rm -f "$IP_FILE"

echo "==================================================="
echo "Backend Deployment Completed Successfully!"
echo "==================================================="
echo "The Medusa backend is now running at: https://api-$ENVIRONMENT.flowdose.xyz"
echo "Admin interface is available at: https://admin-$ENVIRONMENT.flowdose.xyz"
echo ""
echo "To verify the deployment, run:"
echo "curl https://api-$ENVIRONMENT.flowdose.xyz/health"
echo "===================================================" 