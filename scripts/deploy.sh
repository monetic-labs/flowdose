#!/bin/bash
set -e

# Default environment
ENV=${1:-staging}

echo "==================================================="
echo "Deploying FlowDose ($ENV environment)"
echo "==================================================="

# Validate environment
if [[ ! "$ENV" =~ ^(staging|production)$ ]]; then
    echo "Error: Invalid environment. Use 'staging' or 'production'"
    exit 1
fi

# Check if Terraform output is available
cd ../terraform
echo "Retrieving server IPs from Terraform state..."

# Get backend IP from Terraform state
BACKEND_IP=$(terraform output -json backend_ip | jq -r '.')
if [ -z "$BACKEND_IP" ] || [ "$BACKEND_IP" == "null" ]; then
    echo "Error: Could not get backend IP from Terraform state"
    echo "Usage: ./deploy.sh [environment] [backend_ip] [storefront_ip]"
    echo "If you want to specify IPs manually, provide them as arguments"
    BACKEND_IP=${2:-""}
fi

# Get storefront IP from Terraform state
STOREFRONT_IP=$(terraform output -json storefront_ip | jq -r '.')
if [ -z "$STOREFRONT_IP" ] || [ "$STOREFRONT_IP" == "null" ]; then
    echo "Error: Could not get storefront IP from Terraform state"
    echo "Usage: ./deploy.sh [environment] [backend_ip] [storefront_ip]"
    echo "If you want to specify IPs manually, provide them as arguments"
    STOREFRONT_IP=${3:-""}
fi

# Validate IPs
if [ -z "$BACKEND_IP" ] || [ -z "$STOREFRONT_IP" ]; then
    echo "Error: Backend or Storefront IP address not provided"
    exit 1
fi

echo "Using Backend IP: $BACKEND_IP"
echo "Using Storefront IP: $STOREFRONT_IP"

# Return to scripts directory
cd ../scripts

# Deploy backend
echo "Deploying backend..."
./deploy-backend.sh $ENV $BACKEND_IP

# Deploy storefront
echo "Deploying storefront..."
./deploy-storefront.sh $ENV $STOREFRONT_IP

echo "==================================================="
echo "FlowDose deployment completed successfully!"
echo "===================================================" 