output "backend_env_path" {
  description = "Path to the generated backend environment file"
  value       = local_file.backend_env.filename
}

output "frontend_env_path" {
  description = "Path to the generated frontend environment file"
  value       = local_file.frontend_env.filename
}

output "backend_env_upload_id" {
  description = "ID of the backend environment upload resource"
  value       = length(null_resource.upload_backend_env) > 0 ? null_resource.upload_backend_env[0].id : null
}

output "frontend_env_upload_id" {
  description = "ID of the frontend environment upload resource"
  value       = length(null_resource.upload_frontend_env) > 0 ? null_resource.upload_frontend_env[0].id : null
} 