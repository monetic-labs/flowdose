output "backend_env_path" {
  description = "Path to the generated backend environment file"
  value       = local_file.backend_env.filename
}

output "frontend_env_path" {
  description = "Path to the generated frontend environment file"
  value       = local_file.frontend_env.filename
}

output "id" {
  description = "Identifier for use as a dependency hook"
  value       = "${local_file.backend_env.id}-${local_file.frontend_env.id}"
} 