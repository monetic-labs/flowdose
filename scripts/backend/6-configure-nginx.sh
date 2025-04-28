#!/bin/bash
set -e  # Exit immediately if a command fails

# Default parameters
SERVER_IP=${1}
SSH_USER=${2:-root}
SSH_KEY_PATH=${3:-~/.ssh/flowdose-do}
ENVIRONMENT=${4:-staging}

# Validate parameters
if [ -z "$SERVER_IP" ]; then
  echo "ERROR: Server IP address is required"
  echo "Usage: $0 <server_ip> [ssh_user] [ssh_key_path] [environment]"
  exit 1
fi

echo "==================================================="
echo "Configuring Nginx for Backend API and Admin Panel"
echo "==================================================="
echo "Server IP: $SERVER_IP"
echo "SSH User: $SSH_USER"
echo "Environment: $ENVIRONMENT"

API_DOMAIN="api-${ENVIRONMENT}.flowdose.xyz"
ADMIN_DOMAIN="admin-${ENVIRONMENT}.flowdose.xyz"

TMP_API_CONFIG_FILE="/tmp/nginx_api_config_$$"  # Use process ID for uniqueness
TMP_ADMIN_CONFIG_FILE="/tmp/nginx_admin_config_$$"

# Cleanup trap for temporary files
trap 'rm -f "$TMP_API_CONFIG_FILE" "$TMP_ADMIN_CONFIG_FILE"' EXIT

# Generate Nginx configuration content for API locally
echo "Generating API Nginx config..."
cat << EOC > "$TMP_API_CONFIG_FILE"
server {
    listen 80;
    server_name ${API_DOMAIN};

    location / {
        proxy_pass http://localhost:9000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOC

# Generate Nginx configuration content for Admin Panel locally
echo "Generating Admin Nginx config..."
cat << EOC > "$TMP_ADMIN_CONFIG_FILE"
server {
    listen 80;
    server_name ${ADMIN_DOMAIN};

    root /usr/share/nginx/admin;
    index index.html;

    # Handle static assets with correct path using alias
    location /app/assets/ {
        alias /usr/share/nginx/admin/assets/;
        expires 30d;
        add_header Cache-Control "public, max-age=2592000";
        # Return 404 directly if asset not found in alias path, prevents fallback to index.html
        try_files \$uri =404;
    }

    # Handle SPA routing
    location / {
        try_files \$uri \$uri/ /index.html;
        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-XSS-Protection "1; mode=block";
        add_header X-Content-Type-Options "nosniff";
    }
}
EOC

echo "Uploading Nginx configurations to server..."
scp -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$TMP_API_CONFIG_FILE" "$TMP_ADMIN_CONFIG_FILE" "${SSH_USER}@${SERVER_IP}:/tmp/"

REMOTE_TMP_API_CONFIG="/tmp/$(basename $TMP_API_CONFIG_FILE)"
REMOTE_TMP_ADMIN_CONFIG="/tmp/$(basename $TMP_ADMIN_CONFIG_FILE)"

echo "Applying Nginx configuration on the server..."
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$SSH_USER@$SERVER_IP" bash -s -- "$API_DOMAIN" "$ADMIN_DOMAIN" "$REMOTE_TMP_API_CONFIG" "$REMOTE_TMP_ADMIN_CONFIG" << 'EOF'
  set -e # Ensure remote commands also exit on error
  # Read arguments passed via bash -s
  ARG_API_DOMAIN="$1"
  ARG_ADMIN_DOMAIN="$2"
  ARG_REMOTE_TMP_API_CONFIG="$3"
  ARG_REMOTE_TMP_ADMIN_CONFIG="$4"

  # Ensure target directories exist
  echo "Ensuring Nginx config directories exist..."
  sudo mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

  # Move uploaded config files into place
  echo "Moving Nginx config files into place..."
  sudo mv "$ARG_REMOTE_TMP_API_CONFIG" "/etc/nginx/sites-available/${ARG_API_DOMAIN}"
  sudo mv "$ARG_REMOTE_TMP_ADMIN_CONFIG" "/etc/nginx/sites-available/${ARG_ADMIN_DOMAIN}"

  # Remove potential old/conflicting default symlinks
  echo "Removing old default Nginx symlinks if they exist..."
  sudo rm -f /etc/nginx/sites-enabled/default
  sudo rm -f /etc/nginx/sites-enabled/flowdose # Remove old one if present

  # Enable new sites by creating symlinks
  echo "Enabling new Nginx sites..."
  sudo ln -sf "/etc/nginx/sites-available/${ARG_API_DOMAIN}" "/etc/nginx/sites-enabled/${ARG_API_DOMAIN}"
  sudo ln -sf "/etc/nginx/sites-available/${ARG_ADMIN_DOMAIN}" "/etc/nginx/sites-enabled/${ARG_ADMIN_DOMAIN}"

  # Test Nginx configuration
  echo 'Testing Nginx configuration...'
  sudo nginx -t
  if [ $? -ne 0 ]; then
    echo 'ERROR: Nginx configuration test failed'
    # Optional: Display the problematic config file content on failure
    echo "--- Content of /etc/nginx/sites-available/${ARG_API_DOMAIN} ---"
    sudo cat "/etc/nginx/sites-available/${ARG_API_DOMAIN}"
    echo "--- Content of /etc/nginx/sites-available/${ARG_ADMIN_DOMAIN} ---"
    sudo cat "/etc/nginx/sites-available/${ARG_ADMIN_DOMAIN}"
    exit 1
  fi

  # Reload Nginx
  echo 'Reloading Nginx...'
  sudo systemctl reload nginx

  echo 'Nginx configured and reloaded successfully for API and Admin.'
  exit 0
EOF

# Check the exit status of the SSH command
if [ $? -eq 0 ]; then
  echo -e "\nNginx configuration applied successfully."
else
  echo -e "\nNginx configuration failed."
  exit 1
fi

echo "==================================================="
echo "Nginx configuration step completed!"
echo "===================================================" 