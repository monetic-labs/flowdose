variable "backend_ip" {
  description = "IP address of the backend server"
  type        = string
}

variable "storefront_ip" {
  description = "IP address of the storefront server"
  type        = string
}

variable "api_domain" {
  description = "Domain name for the API (e.g., api-staging.flowdose.xyz)"
  type        = string
}

variable "admin_domain" {
  description = "Domain name for the admin panel (e.g., admin-staging.flowdose.xyz)"
  type        = string
}

variable "storefront_domain" {
  description = "Domain name for the storefront (e.g., staging.flowdose.xyz)"
  type        = string
}

variable "admin_email" {
  description = "Email address for Let's Encrypt notifications"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for server access"
  type        = string
}

variable "enable_ssl" {
  description = "Whether to enable SSL certificate provisioning"
  type        = bool
  default     = true
} 