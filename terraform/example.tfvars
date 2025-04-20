# DigitalOcean API token
do_token = "your_do_api_token"

# Region settings
region        = "sfo3"
spaces_region = "sfo3"

# Environment
environment = "staging" # or "production"

# Droplet configuration
droplet_image           = "ubuntu-22-04-x64"
backend_droplet_size    = "s-2vcpu-2gb"
storefront_droplet_size = "s-2vcpu-2gb"
ssh_key_ids             = ["12345678"] # Your SSH key IDs
additional_tags         = []

# Database configuration
db_size    = "db-s-1vcpu-1gb"
redis_size = "db-s-1vcpu-1gb"

# Admin user (for sensitive values, use secrets.tfvars)
admin_email = "admin@flowdose.xyz"
# admin_password = "secure_password"  # Use secrets.tfvars

# Security (use secrets.tfvars for these)
# jwt_secret = "your_jwt_secret"
# cookie_secret = "your_cookie_secret"
# revalidate_secret = "your_revalidate_secret"

# Email configuration (use secrets.tfvars for api_key)
# resend_api_key = "your_resend_api_key"
resend_from = "no-reply@flowdose.xyz"

# Spaces/S3 credentials (use secrets.tfvars for these)
# spaces_access_key = "your_spaces_access_key"
# spaces_secret_key = "your_spaces_secret_key"

# Medusa (will be generated after deployment)
# medusa_publishable_key = ""

# Region settings
default_region = "US"

# Analytics (if any)
google_analytics_id = ""

# Deployment
# ssh_private_key_path = "/path/to/private_key"  # Use secrets.tfvars
force_deploy_backend    = false
force_deploy_storefront = false

# Note: Create a copy of this file named 'terraform.tfvars' with your actual values
# Create another file named 'secrets.tfvars' for sensitive values
# Both terraform.tfvars and secrets.tfvars will be ignored by git for security 