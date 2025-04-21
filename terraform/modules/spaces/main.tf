# Use local values for existing bucket instead of creating resources
# This avoids Terraform trying to recreate or modify existing Spaces buckets
locals {
  bucket_name = var.name
  bucket_region = var.region
  bucket_domain_name = "${var.name}.${var.region}.digitaloceanspaces.com"
  endpoint = "https://${var.region}.digitaloceanspaces.com/${var.name}"
  urn = "do:space:${var.name}"
  name = var.name
}

# CORS and CDN configuration is handled manually outside of Terraform
# to prevent modification of existing resources. 