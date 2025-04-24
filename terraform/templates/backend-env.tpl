# Medusa Backend Environment Configuration

# Core Settings
NODE_ENV=${node_env}
BACKEND_URL=${api_url}
PORT=9000

# CORS Settings
ADMIN_CORS=${admin_cors}
STORE_CORS=${store_cors}
AUTH_CORS=${auth_cors}

# Security Keys
JWT_SECRET=${jwt_secret}
COOKIE_SECRET=${cookie_secret}

# Storage Configuration
MEDUSA_DEFAULT_FILE_SERVICE=spaces
SPACES_URL=${spaces_url}
SPACES_BUCKET=${spaces_bucket}
SPACES_ACCESS_KEY_ID=${spaces_key}
SPACES_SECRET_ACCESS_KEY=${spaces_secret}
SPACES_REGION=${spaces_region}

# Database
DATABASE_URL=${db_url}
DB_USERNAME=${db_username}
DB_PASSWORD=${db_password}
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_DATABASE=${db_database}

# Redis
REDIS_URL=${redis_url}
CACHE_REDIS_URL=${redis_url}
EVENTS_REDIS_URL=${redis_url}

# Admin User (for seeding)
MEDUSA_ADMIN_EMAIL=${admin_email}
MEDUSA_ADMIN_PASSWORD=${admin_password}

# Email Provider (Resend)
RESEND_API_KEY=${resend_key}
RESEND_FROM=${resend_from}

# Plugins Configuration
# For email, payment processors, etc. - add as needed 