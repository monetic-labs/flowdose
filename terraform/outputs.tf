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
