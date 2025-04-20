output "backend_ssl_id" {
  description = "ID of the backend SSL certificate resource"
  value       = null_resource.backend_ssl.id
}

output "storefront_ssl_id" {
  description = "ID of the storefront SSL certificate resource"
  value       = null_resource.storefront_ssl.id
} 