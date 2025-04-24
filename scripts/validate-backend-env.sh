#!/bin/bash
set -e

ENV=${1:-staging}
ENV_FILE="backend/.env.${ENV}"
TMP_ENV_FILE="/tmp/backend.env"

echo "Validating backend environment variables for $ENV environment..."

# Required environment variables for Medusa backend
REQUIRED_VARS=(
  "DATABASE_URL"
  "REDIS_URL"
  "JWT_SECRET"
  "COOKIE_SECRET"
  "MEDUSA_ADMIN_CORS"
  "MEDUSA_STORE_CORS"
  "STORE_CORS"
  "MEDUSA_BACKEND_URL"
)

# Check if we're in CI environment
if [ -n "$GITHUB_ACTIONS" ]; then
  echo "CI environment detected, creating .env file from secrets..."
  
  # In GitHub Actions, we would use secrets to create the .env file
  echo "Creating temporary env file..."
  > $TMP_ENV_FILE
  
  # Add each required variable from GitHub secrets
  for var in "${REQUIRED_VARS[@]}"; do
    # This assumes the secrets are named like BACKEND_DATABASE_URL, BACKEND_REDIS_URL, etc.
    github_var="BACKEND_${var}"
    
    if [ -z "${!github_var}" ]; then
      echo "Error: GitHub secret $github_var is not set."
      exit 1
    fi
    
    echo "$var=${!github_var}" >> $TMP_ENV_FILE
  done
  
  echo "Environment file created successfully."
else
  # In local/manual deployment, check if the env file exists
  if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file $ENV_FILE not found."
    exit 1
  fi
  
  # Check that all required variables are set in the env file
  for var in "${REQUIRED_VARS[@]}"; do
    if ! grep -q "^$var=" "$ENV_FILE"; then
      echo "Error: Required environment variable $var is not set in $ENV_FILE."
      exit 1
    fi
  done
  
  # Copy the env file to a temporary location
  cp "$ENV_FILE" "$TMP_ENV_FILE"
  echo "Environment file validated and copied to $TMP_ENV_FILE"
fi

echo "Backend environment validation completed." 