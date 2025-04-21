variable "node_env" {
  description = "The Node environment (development, staging, production)"
  type        = string
  default     = "production"
}

variable "environment" {
  description = "The deployment environment (staging, production)"
  type        = string
  default     = "staging"
}

# Backend variables
variable "backend_droplet_id" {
  description = "The ID of the backend droplet (if created)"
  type        = string
  default     = ""
}

variable "backend_droplet_ip" {
  description = "The IP address of the backend droplet"
  type        = string
  default     = ""
}

variable "backend_app_dir" {
  description = "Directory where the backend app is located on the server"
  type        = string
  default     = ""
}

variable "backend_env_upload_id" {
  description = "ID of the backend environment upload resource"
  type        = string
  default     = ""
}

variable "force_deploy_backend" {
  description = "Force backend deployment even if environment hasn't changed"
  type        = bool
  default     = false
}

# Storefront variables
variable "storefront_droplet_id" {
  description = "The ID of the storefront droplet (if created)"
  type        = string
  default     = ""
}

variable "storefront_droplet_ip" {
  description = "The IP address of the storefront droplet"
  type        = string
  default     = ""
}

variable "storefront_app_dir" {
  description = "Directory where the storefront app is located on the server"
  type        = string
  default     = ""
}

variable "frontend_env_upload_id" {
  description = "ID of the frontend environment upload resource"
  type        = string
  default     = ""
}

variable "force_deploy_storefront" {
  description = "Force storefront deployment even if environment hasn't changed"
  type        = bool
  default     = false
}

# SSH
variable "ssh_private_key_path" {
  description = "Path to SSH private key for server access"
  type        = string
} 