variable "name" {
  description = "The name of the Spaces bucket"
  type        = string
}

variable "region" {
  description = "The region where the bucket resides"
  type        = string
  default     = "sfo3"
}

variable "acl" {
  description = "Canned ACL applied on bucket creation (private or public-read)"
  type        = string
  default     = "private"
}

variable "force_destroy" {
  description = "Allow deletion of non-empty bucket"
  type        = bool
  default     = false
}

variable "enable_versioning" {
  description = "Enable versioning for the Spaces bucket"
  type        = bool
  default     = false
}

variable "cors_rules" {
  description = "List of CORS rules"
  type = list(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    max_age_seconds = number
  }))
  default = []
}

variable "lifecycle_rules" {
  description = "List of lifecycle rules"
  type = list(object({
    enabled                                = bool
    abort_incomplete_multipart_upload_days = optional(number)
    expiration = optional(object({
      days = number
    }))
    noncurrent_version_expiration = optional(object({
      days = number
    }))
  }))
  default = []
}

variable "enable_cdn" {
  description = "Enable CDN for the Spaces bucket"
  type        = bool
  default     = false
}

variable "cdn_ttl" {
  description = "The TTL for the CDN cache"
  type        = number
  default     = 3600
}

variable "cdn_custom_domain" {
  description = "The custom domain for the CDN endpoint"
  type        = string
  default     = null
} 