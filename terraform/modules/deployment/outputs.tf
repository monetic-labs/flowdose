output "backend_deploy_id" {
  description = "ID of the backend deployment resource"
  value       = null_resource.deploy_backend.id
}

output "storefront_deploy_id" {
  description = "ID of the storefront deployment resource"
  value       = null_resource.deploy_storefront.id
} 