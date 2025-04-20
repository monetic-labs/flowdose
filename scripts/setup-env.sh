#!/bin/bash
set -e

# Default environment
ENV=${1:-staging}

echo "==================================================="
echo "Setting up FlowDose environment ($ENV)"
echo "==================================================="

# Validate environment
if [[ ! "$ENV" =~ ^(staging|production)$ ]]; then
    echo "Error: Invalid environment. Use 'staging' or 'production'"
    exit 1
fi

# SSH variables
SSH_USER="root"
BACKEND_IP=${2:-""}
STOREFRONT_IP=${3:-""}

if [ -z "$BACKEND_IP" ] || [ -z "$STOREFRONT_IP" ]; then
    echo "Error: Backend or Storefront IP not provided"
    echo "Usage: ./setup-env.sh [environment] [backend_ip] [storefront_ip]"
    exit 1
fi

# Get environment variables from Terraform
cd ../terraform
echo "Loading environment variables from Terraform..."

# Extract variables for backend
DATABASE_URL=$(terraform output -json database_url | jq -r '.')
REDIS_URL=$(terraform output -json redis_url | jq -r '.')
JWT_SECRET=$(terraform output -json jwt_secret | jq -r '.')
COOKIE_SECRET=$(terraform output -json cookie_secret | jq -r '.')
ADMIN_EMAIL=$(terraform output -json admin_email | jq -r '.')
ADMIN_PASSWORD=$(terraform output -json admin_password | jq -r '.')
SPACES_ENDPOINT=$(terraform output -json spaces_endpoint | jq -r '.')
SPACES_REGION=$(terraform output -json spaces_region | jq -r '.')
SPACES_BUCKET=$(terraform output -json spaces_bucket | jq -r '.')
SPACES_ACCESS_KEY=$(terraform output -json spaces_access_key | jq -r '.')
SPACES_SECRET_KEY=$(terraform output -json spaces_secret_key | jq -r '.')
RESEND_API_KEY=$(terraform output -json resend_api_key | jq -r '.')
RESEND_FROM=$(terraform output -json resend_from | jq -r '.')

# Return to scripts directory
cd ../scripts

# Create backend .env file and upload to server
echo "Setting up backend environment..."
cat << EOF > backend.env
NODE_ENV=$ENV
PORT=9000
DATABASE_URL=$DATABASE_URL
REDIS_URL=$REDIS_URL
JWT_SECRET=$JWT_SECRET
COOKIE_SECRET=$COOKIE_SECRET
ADMIN_CORS=https://admin-$ENV.flowdose.xyz
STORE_CORS=https://$( [ "$ENV" == "production" ] && echo "flowdose.xyz" || echo "$ENV.flowdose.xyz" )
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_PASSWORD=$ADMIN_PASSWORD
S3_ENDPOINT=$SPACES_ENDPOINT
S3_BUCKET=$SPACES_BUCKET
S3_REGION=$SPACES_REGION
S3_ACCESS_KEY=$SPACES_ACCESS_KEY
S3_SECRET_KEY=$SPACES_SECRET_KEY
RESEND_API_KEY=$RESEND_API_KEY
RESEND_FROM=$RESEND_FROM
EOF

# Copy backend .env to server
scp -o StrictHostKeyChecking=no backend.env $SSH_USER@$BACKEND_IP:/var/www/flowdose/backend/.env
rm backend.env

# Create publishable key for medusa
echo "Generating publishable API key..."
ssh -o StrictHostKeyChecking=no $SSH_USER@$BACKEND_IP << 'EOF'
    cd /var/www/flowdose/backend
    MEDUSA_PUBLISHABLE_KEY=$(node scripts/generate-publishable-key.js 2>/dev/null || echo "")
    echo "Publishable key created: $MEDUSA_PUBLISHABLE_KEY"
    echo "MEDUSA_PUBLISHABLE_KEY=$MEDUSA_PUBLISHABLE_KEY" >> .env
EOF

# Get the generated publishable key
PUBLISHABLE_KEY=$(ssh -o StrictHostKeyChecking=no $SSH_USER@$BACKEND_IP "grep MEDUSA_PUBLISHABLE_KEY /var/www/flowdose/backend/.env | cut -d= -f2")

# Create storefront .env file and upload to server
echo "Setting up storefront environment..."
cat << EOF > storefront.env
# Environment
NODE_ENV=$ENV

# Endpoints
NEXT_PUBLIC_MEDUSA_BACKEND_URL=https://api-$ENV.flowdose.xyz
NEXT_PUBLIC_BASE_URL=https://$( [ "$ENV" == "production" ] && echo "flowdose.xyz" || echo "$ENV.flowdose.xyz" )

# API keys
NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=$PUBLISHABLE_KEY
REVALIDATE_SECRET=$REVALIDATE_SECRET

# Region settings
NEXT_PUBLIC_DEFAULT_REGION=US

# Analytics
NEXT_PUBLIC_GOOGLE_ANALYTICS_ID=$GOOGLE_ANALYTICS_ID
EOF

# Copy storefront .env to server
scp -o StrictHostKeyChecking=no storefront.env $SSH_USER@$STOREFRONT_IP:/var/www/flowdose/storefront/.env
rm storefront.env

echo "Environment setup completed successfully!" 