#!/bin/bash
set -e

# Script to upload environment files to the servers
echo "Uploading environment files for ${environment} environment..."

# Upload backend environment
echo "Uploading backend environment to ${backend_ip}..."
scp -o StrictHostKeyChecking=no "${PWD}/generated/backend-${environment}.env" root@${backend_ip}:/tmp/backend.env
ssh -o StrictHostKeyChecking=no root@${backend_ip} "mv /tmp/backend.env /var/www/flowdose/backend/.env"

# Upload storefront environment
echo "Uploading storefront environment to ${storefront_ip}..."
scp -o StrictHostKeyChecking=no "${PWD}/generated/storefront-${environment}.env" root@${storefront_ip}:/tmp/storefront.env
ssh -o StrictHostKeyChecking=no root@${storefront_ip} "mv /tmp/storefront.env /var/www/flowdose/storefront/.env.local"

echo "Environment files uploaded successfully!" 