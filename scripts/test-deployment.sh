#!/bin/bash
set -e

# Test script for deployment in a simulated CI environment
ENV=${1:-test}

echo "==================================================="
echo "Testing deployment scripts in simulated CI environment"
echo "Environment: $ENV"
echo "==================================================="

# Set simulated GitHub Actions environment
export GITHUB_ACTIONS=true

# Set simulated secrets
export BACKEND_DATABASE_URL="postgresql://user:pass@db.example.com:5432/${ENV}_db"
export BACKEND_REDIS_URL="redis://redis.example.com:6379"
export BACKEND_JWT_SECRET="example_jwt_secret"
export BACKEND_COOKIE_SECRET="example_cookie_secret"
export BACKEND_MEDUSA_ADMIN_CORS="https://admin-${ENV}.flowdose.xyz"
export BACKEND_MEDUSA_STORE_CORS="https://${ENV}.flowdose.xyz"
export BACKEND_STORE_CORS="https://${ENV}.flowdose.xyz"
export BACKEND_MEDUSA_BACKEND_URL="https://api-${ENV}.flowdose.xyz"

export STOREFRONT_NEXT_PUBLIC_MEDUSA_BACKEND_URL="https://api-${ENV}.flowdose.xyz"
export STOREFRONT_NEXT_PUBLIC_BASE_URL="https://${ENV}.flowdose.xyz"
export STOREFRONT_REVALIDATE_SECRET="example_revalidate_secret"

# Test backend deployment
echo ""
echo "Testing backend deployment script..."
./scripts/deploy-backend.sh $ENV

# Test storefront deployment
echo ""
echo "Testing storefront deployment script..."
./scripts/deploy-storefront.sh $ENV

# Cleanup
unset GITHUB_ACTIONS
unset BACKEND_DATABASE_URL
unset BACKEND_REDIS_URL
unset BACKEND_JWT_SECRET
unset BACKEND_COOKIE_SECRET
unset BACKEND_MEDUSA_ADMIN_CORS
unset BACKEND_MEDUSA_STORE_CORS
unset BACKEND_STORE_CORS
unset BACKEND_MEDUSA_BACKEND_URL
unset STOREFRONT_NEXT_PUBLIC_MEDUSA_BACKEND_URL
unset STOREFRONT_NEXT_PUBLIC_BASE_URL
unset STOREFRONT_REVALIDATE_SECRET

echo ""
echo "==================================================="
echo "Deployment script tests completed successfully!"
echo "===================================================" 