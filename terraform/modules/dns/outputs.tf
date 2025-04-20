output "domain_name" {
  description = "The domain name"
  value       = digitalocean_domain.flowdose.name
}

output "api_fqdn" {
  description = "Fully qualified domain name for the API"
  value       = "${digitalocean_record.backend_api.name}.${digitalocean_domain.flowdose.name}"
}

output "admin_fqdn" {
  description = "Fully qualified domain name for the admin panel"
  value       = "${digitalocean_record.backend_admin.name}.${digitalocean_domain.flowdose.name}"
}

output "storefront_fqdn" {
  description = "Fully qualified domain name for the storefront"
  value       = digitalocean_record.storefront.name == "@" ? digitalocean_domain.flowdose.name : "${digitalocean_record.storefront.name}.${digitalocean_domain.flowdose.name}"
} 