#!/bin/bash
set -e  # Exit immediately if a command fails

# Default parameters
SERVER_IP=${1}
SSH_USER=${2:-root}
SSH_KEY_PATH=${3:-~/.ssh/flowdose-do}
ENVIRONMENT=${4:-staging}
APP_DIR=${5:-/root/app}
SPACES_BUCKET=${6:-flowdose-state-storage}
SPACES_REGION=${7:-sfo3}
SPACES_ACCESS_KEY=${8}
SPACES_SECRET_KEY=${9}

# Validate parameters
if [ -z "$SERVER_IP" ]; then
  echo "ERROR: Server IP address is required"
  echo "Usage: $0 <server_ip> [ssh_user] [ssh_key_path] [environment] [app_dir] [spaces_bucket] [spaces_region] [spaces_access_key] [spaces_secret_key]"
  exit 1
fi

if [ -z "$SPACES_ACCESS_KEY" ] || [ -z "$SPACES_SECRET_KEY" ]; then
  echo "ERROR: Spaces access key and secret key are required"
  echo "Usage: $0 <server_ip> [ssh_user] [ssh_key_path] [environment] [app_dir] [spaces_bucket] [spaces_region] [spaces_access_key] [spaces_secret_key]"
  exit 1
fi

echo "==================================================="
echo "Setting up environment files for backend deployment"
echo "==================================================="
echo "Server IP: $SERVER_IP"
echo "SSH User: $SSH_USER"
echo "Environment: $ENVIRONMENT"
echo "App Directory: $APP_DIR"
echo "Spaces Bucket: $SPACES_BUCKET"
echo "Spaces Region: $SPACES_REGION"

# Execute the environment setup commands on the remote server
echo "Starting environment setup..."
ENV_RESULT=$(ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$SSH_USER@$SERVER_IP" <<EOF
# Set variables
ENVIRONMENT="$ENVIRONMENT"
APP_DIR="$APP_DIR"
SPACES_BUCKET="$SPACES_BUCKET"
SPACES_REGION="$SPACES_REGION"
SPACES_ACCESS_KEY="$SPACES_ACCESS_KEY"
SPACES_SECRET_KEY="$SPACES_SECRET_KEY"

# Create app directory if it doesn't exist
mkdir -p \${APP_DIR}/backend

# Install AWS CLI if needed
if ! command -v aws &> /dev/null; then
  echo "Installing AWS CLI..."
  apt-get update
  apt-get install -y awscli
fi

# Set up AWS CLI credentials
export AWS_ACCESS_KEY_ID="\$SPACES_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="\$SPACES_SECRET_KEY"

# Download environment file from Spaces
echo "Downloading environment file from Spaces..."
ENV_FILE="env-files/\$ENVIRONMENT/backend.env"
aws s3 cp --endpoint=https://\$SPACES_REGION.digitaloceanspaces.com s3://\$SPACES_BUCKET/\$ENV_FILE \${APP_DIR}/backend/.env

# Check if download was successful
if [ ! -f "\${APP_DIR}/backend/.env" ]; then
  echo "ERROR: Failed to download environment file from Spaces"
  exit 1
fi

# Check file size to ensure it's not empty
FILE_SIZE=\$(stat -c%s "\${APP_DIR}/backend/.env")
if [ "\$FILE_SIZE" -eq 0 ]; then
  echo "ERROR: Downloaded environment file is empty"
  exit 1
fi

# Create environment-specific .env file
cp \${APP_DIR}/backend/.env \${APP_DIR}/backend/.env.\$ENVIRONMENT

# Make sure NODE_ENV is set correctly
grep -q "NODE_ENV=\$ENVIRONMENT" \${APP_DIR}/backend/.env || echo "NODE_ENV=\$ENVIRONMENT" >> \${APP_DIR}/backend/.env

# Add SSL bypass for Digital Ocean database (if not already present)
grep -q "NODE_TLS_REJECT_UNAUTHORIZED=0" \${APP_DIR}/backend/.env || echo "NODE_TLS_REJECT_UNAUTHORIZED=0" >> \${APP_DIR}/backend/.env

# Verify environment file
echo "Environment file contents (sanitized):"
grep -v -E 'SECRET|PASSWORD|KEY' \${APP_DIR}/backend/.env | sed 's/\(DATABASE_URL=postgresql:\/\/[^:]*\):[^@]*\(@.*\)/\1:****\2/'

echo "Environment setup completed successfully."
exit 0
EOF
)

# Check the exit status of the SSH command
if [ $? -eq 0 ]; then
  echo -e "$ENV_RESULT"
  echo -e "\nEnvironment setup completed successfully."
else
  echo -e "$ENV_RESULT"
  echo -e "\nEnvironment setup failed."
  exit 1
fi

echo "==================================================="
echo "Environment setup completed!"
echo "===================================================" 