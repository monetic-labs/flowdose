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

# Get environment variables from Terraform or use defaults
cd ../terraform
echo "Loading environment variables from Terraform..."

# Helper function to get terraform output with fallback
get_tf_output() {
    local output_name=$1
    local default_value=$2
    local result
    
    # Try to get the value from terraform output
    result=$(terraform output -json $output_name 2>/dev/null || echo "null")
    
    # Check if result is valid JSON and not null
    if echo "$result" | jq -e . >/dev/null 2>&1 && [ "$result" != "null" ]; then
        echo "$result" | jq -r '.'
    else
        echo "$default_value"
    fi
}

# Extract variables with fallbacks
DATABASE_URL=$(get_tf_output database_url "postgresql://postgres:password@postgres-flowdose-staging.db.ondigitalocean.com:25060/postgres?sslmode=require")
REDIS_URL=$(get_tf_output redis_url "redis://redis-flowdose-staging.db.ondigitalocean.com:25061")
JWT_SECRET=$(get_tf_output jwt_secret "test-jwt-secret-for-staging-environment")
COOKIE_SECRET=$(get_tf_output cookie_secret "test-cookie-secret-for-staging-environment")
ADMIN_EMAIL=$(get_tf_output admin_email "admin@flowdose.xyz")
ADMIN_PASSWORD=$(get_tf_output admin_password "flowdose123")
SPACES_ENDPOINT=$(get_tf_output spaces_endpoint "sfo3.digitaloceanspaces.com")
SPACES_REGION=$(get_tf_output spaces_region "sfo3")
SPACES_BUCKET=$(get_tf_output spaces_bucket "staging-flowdose-bucket")
SPACES_ACCESS_KEY=$(get_tf_output spaces_access_key "$SPACES_ACCESS_KEY_ID")
SPACES_SECRET_KEY=$(get_tf_output spaces_secret_key "$SPACES_SECRET_ACCESS_KEY")
RESEND_API_KEY=$(get_tf_output resend_api_key "re_123456789")
RESEND_FROM=$(get_tf_output resend_from "no-reply@flowdose.xyz")
REVALIDATE_SECRET=$(get_tf_output revalidate_secret "test-revalidate-secret")
GOOGLE_ANALYTICS_ID=$(get_tf_output google_analytics_id "")

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
    MEDUSA_PUBLISHABLE_KEY=$(node scripts/generate-publishable-key.js 2>/dev/null || echo "pk_staging_placeholder")
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