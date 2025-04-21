output "backend_ssl_id" {
  description = "ID of the backend SSL certificate resource"
  value       = local.backend_ssl_id
}

output "storefront_ssl_id" {
  description = "ID of the storefront SSL certificate resource"
  value       = local.storefront_ssl_id
} 