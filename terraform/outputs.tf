# Droplet Information
output "backend_droplet_ip" {
  description = "The IPv4 address of the backend droplet"
  value       = module.backend_droplet.ipv4_address
}

output "storefront_droplet_ip" {
  description = "The IPv4 address of the storefront droplet"
  value       = module.storefront_droplet.ipv4_address
}

# Database Information
output "database_host" {
  description = "The hostname of the database"
  value       = module.postgres_db.host
  sensitive   = true
}

output "database_port" {
  description = "The port of the database"
  value       = module.postgres_db.port
}

output "database_name" {
  description = "The name of the database"
  value       = module.postgres_db.database_names[0]
}

# Redis Information
output "redis_host" {
  description = "The hostname of the Redis instance"
  value       = module.redis_db.host
  sensitive   = true
}

output "redis_port" {
  description = "The port of the Redis instance"
  value       = module.redis_db.port
}

# URLs
output "api_url" {
  description = "The URL of the backend API"
  value       = "https://${module.dns.api_fqdn}"
}

output "admin_url" {
  description = "The URL of the admin panel"
  value       = "https://${module.dns.admin_fqdn}"
}

output "storefront_url" {
  description = "The URL of the storefront"
  value       = "https://${module.dns.storefront_fqdn}"
}

# Storage
output "spaces_bucket" {
  description = "The name of the Spaces bucket"
  value       = module.media_storage.name
}

output "spaces_endpoint" {
  description = "The endpoint of the Spaces bucket"
  value       = module.media_storage.endpoint
}

# Deployment Information
output "backend_env_path" {
  description = "Path to the generated backend environment file"
  value       = module.env_config_generation.backend_env_path
}

output "frontend_env_path" {
  description = "Path to the generated frontend environment file"
  value       = module.env_config_generation.frontend_env_path
}

# Server IPs
output "backend_ip" {
  description = "The public IP address of the backend server"
  value       = module.backend_droplet.ipv4_address
}

output "storefront_ip" {
  description = "The public IP address of the storefront server"
  value       = module.storefront_droplet.ipv4_address
}

# Database and Redis
output "database_url" {
  description = "The PostgreSQL database connection URL"
  value       = module.postgres_db.uri
  sensitive   = true
}

output "redis_url" {
  description = "The Redis cache connection URL"
  value       = module.redis_db.uri
  sensitive   = true
}

# Spaces configuration
output "spaces_region" {
  description = "The DigitalOcean Spaces region"
  value       = var.spaces_region
}

# Secrets (sensitive outputs)
output "spaces_access_key" {
  description = "The DigitalOcean Spaces access key"
  value       = var.spaces_access_key
  sensitive   = true
}

output "spaces_secret_key" {
  description = "The DigitalOcean Spaces secret key"
  value       = var.spaces_secret_key
  sensitive   = true
}

output "jwt_secret" {
  description = "The JWT secret for authentication"
  value       = var.jwt_secret
  sensitive   = true
}

output "cookie_secret" {
  description = "The cookie secret for sessions"
  value       = var.cookie_secret
  sensitive   = true
}

output "revalidate_secret" {
  description = "The revalidation secret for Next.js"
  value       = var.revalidate_secret
  sensitive   = true
}

# Admin credentials
output "admin_email" {
  description = "Admin user email"
  value       = var.admin_email
}

output "admin_password" {
  description = "Admin user password"
  value       = var.admin_password
  sensitive   = true
}

# Email service
output "resend_api_key" {
  description = "Resend API key"
  value       = var.resend_api_key
  sensitive   = true
}

output "resend_from" {
  description = "Email address to send from"
  value       = var.resend_from
}

# Analytics
output "google_analytics_id" {
  description = "Google Analytics ID"
  value       = var.google_analytics_id
}
