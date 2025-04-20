# FlowDose Backend Environment Variables (MedusaJS)

# Core Settings
NODE_ENV=${node_env}
PORT=9000

# CORS Settings
ADMIN_CORS=${admin_cors}
STORE_CORS=${store_cors}
AUTH_CORS=${auth_cors}

# Database
DATABASE_URL=${database_url}
DB_USERNAME=${db_username}
DB_PASSWORD=${db_password}
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_DATABASE=${db_database}

# Redis
REDIS_URL=${redis_url}
CACHE_REDIS_URL=${redis_url}
EVENTS_REDIS_URL=${redis_url}

# JWT and Cookies
JWT_SECRET=${jwt_secret}
COOKIE_SECRET=${cookie_secret}

# Admin User (for seeding)
ADMIN_EMAIL=${admin_email}
ADMIN_PASSWORD=${admin_password}

# Email Provider (Resend)
RESEND_API_KEY=${resend_key}
RESEND_FROM=${resend_from}

# File Storage (with common alternative names)
S3_ENDPOINT=${storage_endpoint}
S3_BUCKET=${storage_bucket}
S3_ACCESS_KEY=${storage_access_key}
S3_SECRET_KEY=${storage_secret_key}
S3_FORCE_PATH_STYLE=true
S3_REGION=${spaces_region}

# Alternative storage naming (if needed)
DO_SPACES_ENDPOINT=${storage_endpoint}
DO_SPACES_BUCKET=${storage_bucket}
DO_SPACES_ACCESS_KEY=${storage_access_key}
DO_SPACES_SECRET_KEY=${storage_secret_key}
DO_SPACES_REGION=${spaces_region}

# API Settings
API_URL=https://api-${environment}.flowdose.xyz
MEDUSA_BACKEND_URL=https://api-${environment}.flowdose.xyz

# Deployment Settings
ENABLE_ADMIN=true
ENABLE_PUBLISHABLE_API_KEY=true

# Storefront URL (for admin links)
STORE_URL=https://${environment == "production" ? "" : "${environment}."}flowdose.xyz
