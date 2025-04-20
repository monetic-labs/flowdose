resource "digitalocean_spaces_bucket" "this" {
  name   = var.name
  region = var.region
  acl    = var.acl

  # Optional features
  force_destroy = var.force_destroy

  # Enable versioning if requested
  dynamic "versioning" {
    for_each = var.enable_versioning ? [1] : []
    content {
      enabled = true
    }
  }

  # Lifecycle rules if provided
  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_rules
    content {
      enabled                                = lifecycle_rule.value.enabled
      abort_incomplete_multipart_upload_days = lookup(lifecycle_rule.value, "abort_incomplete_multipart_upload_days", null)

      # Expiration configuration
      dynamic "expiration" {
        for_each = lookup(lifecycle_rule.value, "expiration", null) != null ? [lifecycle_rule.value.expiration] : []
        content {
          days = expiration.value.days
        }
      }

      # Noncurrent version expiration
      dynamic "noncurrent_version_expiration" {
        for_each = lookup(lifecycle_rule.value, "noncurrent_version_expiration", null) != null ? [lifecycle_rule.value.noncurrent_version_expiration] : []
        content {
          days = noncurrent_version_expiration.value.days
        }
      }
    }
  }
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