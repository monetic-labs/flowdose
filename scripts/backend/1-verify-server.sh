#!/bin/bash
set -e  # Exit immediately if a command fails

# Default parameters
SERVER_IP=${1}
SSH_USER=${2:-root}
SSH_KEY_PATH=${3:-~/.ssh/flowdose-do}

# Validate parameters
if [ -z "$SERVER_IP" ]; then
  echo "ERROR: Server IP address is required"
  echo "Usage: $0 <server_ip> [ssh_user] [ssh_key_path]"
  exit 1
fi

echo "==================================================="
echo "Verifying server configuration for backend deployment"
echo "==================================================="
echo "Server IP: $SERVER_IP"
echo "SSH User: $SSH_USER"
echo "SSH Key: $SSH_KEY_PATH"

# Test SSH connection
echo -n "Testing SSH connection... "
if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$SSH_KEY_PATH" "$SSH_USER@$SERVER_IP" "echo Connected successfully" > /dev/null; then
  echo "SUCCESS"
else
  echo "FAILED"
  echo "Cannot connect to server using SSH. Please check IP address and SSH credentials."
  exit 1
fi

# Verify server requirements
echo -n "Checking server requirements... "

# Execute the verification commands on the remote server
VERIFICATION=$(ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$SSH_USER@$SERVER_IP" <<'EOF'
# Create an array to store missing requirements
declare -a missing=()

# Check operating system
echo "Operating System: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"

# Check Node.js
if command -v node &> /dev/null; then
  echo "Node.js: $(node -v)"
else
  echo "Node.js: MISSING"
  missing+=("Node.js")
fi

# Check npm
if command -v npm &> /dev/null; then
  echo "npm: $(npm -v)"
else
  echo "npm: MISSING"
  missing+=("npm")
fi

# Check git
if command -v git &> /dev/null; then
  echo "git: $(git --version)"
else
  echo "git: MISSING"
  missing+=("git")
fi

# Check PM2
if command -v pm2 &> /dev/null; then
  echo "PM2: $(pm2 -v)"
else
  echo "PM2: MISSING"
  missing+=("PM2")
fi

# Check nginx (optional, but recommended)
if command -v nginx &> /dev/null; then
  echo "nginx: $(nginx -v 2>&1)"
else
  echo "nginx: MISSING (optional)"
fi

# Check available disk space
echo "Disk Space: $(df -h / | awk 'NR==2 {print $4}') available"

# Check memory
echo "Memory: $(free -h | awk 'NR==2 {print $7}') available"

# Check if root app directory exists
if [ -d "/root/app" ]; then
  echo "App directory: EXISTS"
else
  echo "App directory: MISSING (will be created)"
fi

# Print missing requirements
if [ ${#missing[@]} -gt 0 ]; then
  echo "MISSING REQUIREMENTS: ${missing[*]}"
  exit 1
else
  echo "All requirements satisfied!"
  exit 0
fi
EOF
)

# Check the exit status of the SSH command
if [ $? -eq 0 ]; then
  echo -e "SUCCESS\n"
  echo "$VERIFICATION"
  echo -e "\nServer is ready for deployment."
else
  echo -e "FAILED\n"
  echo "$VERIFICATION"
  echo -e "\nServer is missing some requirements. Please install them before proceeding."
  exit 1
fi

echo "==================================================="
echo "Server verification completed successfully!"
echo "===================================================" 