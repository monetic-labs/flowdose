variable "name" {
  description = "The name of the Redis cluster"
  type        = string
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7"
}

variable "size" {
  description = "Database droplet size"
  type        = string
  default     = "db-s-1vcpu-1gb"
}

variable "region" {
  description = "The region to start the Redis cluster in"
  type        = string
  default     = "sfo3"
}

variable "node_count" {
  description = "Number of nodes in the cluster"
  type        = number
  default     = 1
}

variable "tags" {
  description = "A list of tag names to be applied to the Redis cluster"
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  description = "The ID of the VPC where the Redis cluster will be located"
  type        = string
  default     = null
}

variable "maintenance_day" {
  description = "The day of the maintenance window"
  type        = string
  default     = "sunday"
}

variable "maintenance_hour" {
  description = "The hour of the maintenance window (UTC)"
  type        = string
  default     = "02:00:00"
}

variable "allowed_ips" {
  description = "List of IP addresses allowed to connect to the Redis cluster"
  type        = list(string)
  default     = []
}

variable "allowed_droplet_ids" {
  description = "List of Droplet IDs allowed to connect to the Redis cluster"
  type        = list(string)
  default     = []
} 