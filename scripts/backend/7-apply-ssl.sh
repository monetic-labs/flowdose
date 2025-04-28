#!/bin/bash
set -e  # Exit immediately if a command fails

# Default parameters
SERVER_IP=${1}
SSH_USER=${2:-root}
SSH_KEY_PATH=${3:-~/.ssh/flowdose-do}
ENVIRONMENT=${4:-staging}
ADMIN_EMAIL=${5} # Email used for Let's Encrypt registration

# Validate parameters
if [ -z "$SERVER_IP" ]; then
  echo "ERROR: Server IP address is required"
  exit 1
fi
if [ -z "$ADMIN_EMAIL" ]; then
  echo "ERROR: Admin email for Certbot is required"
  echo "Usage: $0 <server_ip> [ssh_user] [ssh_key_path] [environment] <admin_email>"
  exit 1
fi

echo "==================================================="
echo "Applying SSL Configuration using Certbot"
echo "==================================================="
echo "Server IP: $SERVER_IP"
echo "SSH User: $SSH_USER"
echo "Environment: $ENVIRONMENT"
echo "Admin Email: $ADMIN_EMAIL"

API_DOMAIN="api-${ENVIRONMENT}.flowdose.xyz"
ADMIN_DOMAIN="admin-${ENVIRONMENT}.flowdose.xyz"

# Command to execute on the remote server
# --nginx: Use the Nginx plugin
# --reinstall: Reinstall the certificate even if it exists (useful for updates/fixes)
# -d: Specify domains
# --non-interactive: Run without prompts
# --agree-tos: Agree to Let's Encrypt Terms of Service
# -m: Specify registration email
REMOTE_COMMAND="sudo certbot --nginx --reinstall -d ${API_DOMAIN} -d ${ADMIN_DOMAIN} --non-interactive --agree-tos -m ${ADMIN_EMAIL}"

# Execute commands on the remote server
echo "Running Certbot to apply SSL configuration..."
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$SSH_USER@$SERVER_IP" "$REMOTE_COMMAND"

# Check the exit status of the SSH command
if [ $? -eq 0 ]; then
  echo -e "\nCertbot ran successfully. SSL should be configured."
else
  echo -e "\nCertbot command failed. Check Certbot logs on the server."
  exit 1
fi

echo "==================================================="
echo "SSL configuration step completed!"
echo "===================================================" 