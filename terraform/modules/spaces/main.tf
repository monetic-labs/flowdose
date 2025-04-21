# Use local values for existing bucket
locals {
  bucket_name = var.name
  bucket_region = var.region
  bucket_domain_name = "${var.name}.${var.region}.digitaloceanspaces.com"
  endpoint = "https://${var.region}.digitaloceanspaces.com/${var.name}"
  urn = "do:space:${var.name}"
  name = var.name
}

# CORS configuration as a separate resource (recommended approach)
resource "digitalocean_spaces_bucket_cors_configuration" "cors" {
  count = length(var.cors_rules) > 0 ? 1 : 0
  
  bucket = digitalocean_spaces_bucket.this.name
  region = digitalocean_spaces_bucket.this.region
  
  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

# Optional CDN for the Spaces bucket
resource "digitalocean_cdn" "cdn" {
  count         = var.enable_cdn ? 1 : 0
  origin        = digitalocean_spaces_bucket.this.bucket_domain_name
  ttl           = var.cdn_ttl
  custom_domain = var.cdn_custom_domain
}

/* CORS configuration commented out
resource "digitalocean_spaces_bucket_cors_configuration" "cors" {
  count = length(var.cors_rules) > 0 ? 1 : 0
  
  bucket = digitalocean_spaces_bucket.this.name
  region = digitalocean_spaces_bucket.this.region
  
  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}
*/

/* CDN also commented out
resource "digitalocean_cdn" "cdn" {
  count         = var.enable_cdn ? 1 : 0
  origin        = digitalocean_spaces_bucket.this.bucket_domain_name
  ttl           = var.cdn_ttl
  custom_domain = var.cdn_custom_domain
} 
*/ 