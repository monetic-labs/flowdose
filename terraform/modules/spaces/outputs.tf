output "id" {
  description = "The name of the bucket"
  value       = digitalocean_spaces_bucket.this.id
}

output "name" {
  description = "The name of the bucket"
  value       = digitalocean_spaces_bucket.this.name
}

output "region" {
  description = "The region of the bucket"
  value       = digitalocean_spaces_bucket.this.region
}

output "bucket_domain_name" {
  description = "The domain name of the bucket"
  value       = digitalocean_spaces_bucket.this.bucket_domain_name
}

output "urn" {
  description = "The uniform resource name for the bucket"
  value       = digitalocean_spaces_bucket.this.urn
}

output "endpoint" {
  description = "The endpoint URL of the bucket"
  value       = "${var.region}.digitaloceanspaces.com/${var.name}"
}

output "cdn_endpoint" {
  description = "The endpoint URL of the CDN"
  value       = var.enable_cdn ? digitalocean_cdn.cdn[0].endpoint : null
} 