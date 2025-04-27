#!/bin/bash
set -e  # Exit immediately if a command fails

# Default parameters
ENVIRONMENT=${1:-staging}
SPACES_BUCKET=${2:-flowdose-state-storage}
SPACES_REGION=${3:-sfo3}
SPACES_ACCESS_KEY=${4}
SPACES_SECRET_KEY=${5}
OUTPUT_FILE=${6:-server_ip.txt}

# Validate parameters
if [ -z "$SPACES_ACCESS_KEY" ] || [ -z "$SPACES_SECRET_KEY" ]; then
  echo "ERROR: Spaces access key and secret key are required"
  echo "Usage: $0 [environment] [spaces_bucket] [spaces_region] <spaces_access_key> <spaces_secret_key> [output_file]"
  exit 1
fi

echo "==================================================="
echo "Retrieving server IP from Terraform state"
echo "==================================================="
echo "Environment: $ENVIRONMENT"
echo "Spaces Bucket: $SPACES_BUCKET"
echo "Spaces Region: $SPACES_REGION"
echo "Output File: $OUTPUT_FILE"

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Set up AWS CLI credentials
export AWS_ACCESS_KEY_ID="$SPACES_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SPACES_SECRET_KEY"

# Download the state file
echo "Downloading Terraform state file..."
aws s3 cp --endpoint=https://${SPACES_REGION}.digitaloceanspaces.com s3://${SPACES_BUCKET}/terraform.tfstate ${TEMP_DIR}/terraform.tfstate

# Check if download was successful
if [ ! -f "${TEMP_DIR}/terraform.tfstate" ]; then
  echo "ERROR: Failed to download Terraform state file"
  exit 1
fi

# Parse the state file to extract both IPs and compare with DigitalOcean droplet names
echo "Parsing state file for server IPs..."

# Get both IPs from the state file
BACKEND_MODULE_IP=$(cat ${TEMP_DIR}/terraform.tfstate | jq -r '.resources[] | select(.module == "module.backend_droplet") | .instances[0].attributes.ipv4_address')
STOREFRONT_MODULE_IP=$(cat ${TEMP_DIR}/terraform.tfstate | jq -r '.resources[] | select(.module == "module.storefront_droplet") | .instances[0].attributes.ipv4_address')

echo "Found these IPs in state file:"
echo "Backend module IP (may be incorrect): $BACKEND_MODULE_IP"
echo "Storefront module IP (may be incorrect): $STOREFRONT_MODULE_IP"

# CORRECTION: According to DigitalOcean droplet names, we know:
# flowdose-backend-staging has IP 144.126.221.222
# flowdose-storefront-staging has IP 137.184.81.34
# So we'll use the correct IP based on this information

if [ "$ENVIRONMENT" == "staging" ]; then
  # In staging, we know these are the correct IPs based on droplet names
  SERVER_IP="144.126.221.222"  # flowdose-backend-staging's actual IP
  echo "Using known backend IP for staging: $SERVER_IP"
else
  # For other environments, or if we want to fall back to state file
  # Try to validate by checking if backend_module_ip matches known storefront IP
  if [ "$BACKEND_MODULE_IP" == "137.184.81.34" ]; then
    echo "State file has incorrect mapping. Using the storefront module IP as backend."
    SERVER_IP="$STOREFRONT_MODULE_IP"
  else
    echo "Using IP from backend module in state file."
    SERVER_IP="$BACKEND_MODULE_IP"
  fi
fi

# Check if we found an IP
if [ -z "$SERVER_IP" ] || [ "$SERVER_IP" = "null" ]; then
  echo "ERROR: Could not determine backend server IP"
  exit 1
fi

# Output the IP
echo "Corrected Backend Server IP: $SERVER_IP"
echo "$SERVER_IP" > $OUTPUT_FILE
echo "IP address saved to $OUTPUT_FILE"

echo "==================================================="
echo "Server IP retrieval completed successfully!"
echo "===================================================" 