output "id" {
  description = "The name of the bucket"
  value       = local.bucket_name
}

output "name" {
  description = "The name of the bucket"
  value       = local.bucket_name
}

output "region" {
  description = "The region of the bucket"
  value       = local.bucket_region
}

output "bucket_domain_name" {
  description = "The domain name of the bucket"
  value       = local.bucket_domain_name
}

output "urn" {
  description = "The uniform resource name for the bucket"
  value       = local.urn
}

output "endpoint" {
  description = "The endpoint URL of the bucket"
  value       = local.endpoint
}

output "cdn_endpoint" {
  description = "The endpoint URL of the CDN"
  value       = var.enable_cdn ? null : null  # No CDN in this case
} 