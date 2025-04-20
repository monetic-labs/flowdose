variable "environment" {
  description = "The environment (staging, production)"
  type        = string
}

# Database connection
variable "database_url" {
  description = "PostgreSQL database URL"
  type        = string
  sensitive   = true
}

# Individual database credentials (for environments that need separate variables)
variable "db_username" {
  description = "Database username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_host" {
  description = "Database host"
  type        = string
  default     = ""
}

variable "db_port" {
  description = "Database port"
  type        = string
  default     = "5432"
}

variable "db_database" {
  description = "Database name"
  type        = string
  default     = ""
}

# Redis connection
variable "redis_url" {
  description = "Redis URL"
  type        = string
  sensitive   = true
}

# Admin user
variable "admin_email" {
  description = "Admin user email"
  type        = string
  default     = "admin@flowdose.xyz"
}

variable "admin_password" {
  description = "Admin user password"
  type        = string
  sensitive   = true
}

# Email service - Resend
variable "resend_api_key" {
  description = "Resend API key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "resend_from" {
  description = "Email address to send from (Resend)"
  type        = string
  default     = "no-reply@flowdose.xyz"
}

# Security
variable "jwt_secret" {
  description = "JWT secret for authentication"
  type        = string
  sensitive   = true
}

variable "cookie_secret" {
  description = "Cookie secret for sessions"
  type        = string
  sensitive   = true
}

variable "revalidate_secret" {
  description = "Secret for revalidating Next.js cache"
  type        = string
  sensitive   = true
}

# Spaces/S3
variable "spaces_endpoint" {
  description = "DigitalOcean Spaces endpoint"
  type        = string
  default     = "sfo3.digitaloceanspaces.com"
}

variable "spaces_region" {
  description = "DigitalOcean Spaces region"
  type        = string
  default     = "sfo3"
}

variable "spaces_bucket" {
  description = "DigitalOcean Spaces bucket name"
  type        = string
}

variable "spaces_access_key" {
  description = "DigitalOcean Spaces access key"
  type        = string
  sensitive   = true
}

variable "spaces_secret_key" {
  description = "DigitalOcean Spaces secret key"
  type        = string
  sensitive   = true
}

# Medusa
variable "medusa_publishable_key" {
  description = "Medusa publishable API key"
  type        = string
  sensitive   = true
}

# Region settings
variable "default_region" {
  description = "Default region for store"
  type        = string
  default     = "US"
}

# Features
variable "search_enabled" {
  description = "Whether to enable search functionality"
  type        = bool
  default     = true
}

# Analytics
variable "google_analytics_id" {
  description = "Google Analytics ID (optional)"
  type        = string
  default     = ""
} 