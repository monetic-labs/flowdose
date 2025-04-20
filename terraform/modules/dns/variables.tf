variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
}

variable "is_production" {
  description = "Whether this is the production environment"
  type        = bool
  default     = false
}

variable "backend_ip" {
  description = "IP address of the backend server"
  type        = string
}

variable "storefront_ip" {
  description = "IP address of the storefront server"
  type        = string
} 