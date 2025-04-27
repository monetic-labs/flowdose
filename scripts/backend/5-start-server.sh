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
echo "Starting Medusa server with PM2"
echo "==================================================="
echo "Server IP: $SERVER_IP"
echo "SSH User: $SSH_USER"
echo "Environment: $ENVIRONMENT"
echo "App Directory: $APP_DIR"

# Execute the server start commands on the remote server
echo "Starting server..."
START_RESULT=$(ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$SSH_USER@$SERVER_IP" <<EOF
# Set variables
ENVIRONMENT="$ENVIRONMENT"
APP_DIR="$APP_DIR"
NODE_ENV="$ENVIRONMENT"
export NODE_ENV

# Verify the server build directory exists
if [ ! -d "\${APP_DIR}/backend/.medusa/server" ]; then
  echo "ERROR: Server build directory not found"
  exit 1
fi

# Stop any running PM2 processes
echo "Stopping existing PM2 processes..."
pm2 stop all 2>/dev/null || true
pm2 delete all 2>/dev/null || true

# Change to the server directory
cd \${APP_DIR}/backend/.medusa/server || exit 1
echo "Current directory: \$(pwd)"

# Verify .env file exists
if [ ! -f ".env" ]; then
  echo "ERROR: .env file not found in server directory"
  exit 1
fi

# Create PM2 configuration file
echo "Creating PM2 configuration file..."
cat > ecosystem.config.js << 'ECOSYSTEMCFG'
module.exports = {
  apps: [
    {
      name: "medusa-server",
      script: "yarn",
      args: "medusa develop",
      cwd: "${APP_DIR}/backend/.medusa/server",
      env: {
        NODE_ENV: "${ENVIRONMENT}",
        NODE_TLS_REJECT_UNAUTHORIZED: "0",
        MEDUSA_WORKER_MODE: "server",
        MEDUSA_ADMIN_API_URL: "http://localhost:9000/admin"
      }
    },
    {
      name: "medusa-worker",
      script: "yarn",
      args: "medusa develop",
      cwd: "${APP_DIR}/backend/.medusa/server",
      env: {
        NODE_ENV: "${ENVIRONMENT}",
        NODE_TLS_REJECT_UNAUTHORIZED: "0",
        MEDUSA_WORKER_MODE: "worker"
      }
    }
  ]
};
ECOSYSTEMCFG

# Copy admin files to Nginx directory if it exists
if [ -d "/usr/share/nginx/admin" ]; then
  echo "Copying admin files to Nginx directory..."
  rm -rf /usr/share/nginx/admin/* || true
  mkdir -p /usr/share/nginx/admin
  if [ -d "\${APP_DIR}/backend/.medusa/server/public/admin" ]; then
    cp -r \${APP_DIR}/backend/.medusa/server/public/admin/* /usr/share/nginx/admin/
  fi
fi

# Start the application with PM2
echo "Starting application with PM2 using ecosystem.config.js..."
pm2 start ecosystem.config.js

# Save the PM2 configuration
echo "Saving PM2 configuration..."
pm2 save

# Set PM2 to start on boot (fixed approach)
echo "Setting PM2 to start on boot..."
pm2 startup systemd -u root --hp /root || true
# This command now directly registers PM2 with systemd without trying to parse the output
systemctl enable pm2-root || true

# Wait for server to start
echo "Waiting for server to start..."
for i in {1..10}; do
  if curl -s http://localhost:9000/health | grep -q "OK"; then
    echo "Server is healthy!"
    break
  elif [ \$i -eq 10 ]; then
    echo "WARNING: Server health check failed, but continuing anyway."
  else
    echo "Waiting for server to start... (attempt \$i/10)"
    sleep 3
  fi
done

# Check if server is running using PM2
echo "PM2 status:"
pm2 list

echo "Server started successfully."
exit 0
EOF
)

# Check the exit status of the SSH command
if [ $? -eq 0 ]; then
  echo -e "$START_RESULT"
  echo -e "\nServer started successfully."
else
  echo -e "$START_RESULT"
  echo -e "\nServer start failed."
  exit 1
fi

echo "==================================================="
echo "Backend server is now running!"
echo "===================================================" 