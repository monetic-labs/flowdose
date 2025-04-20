variable "name" {
  description = "The Droplet name"
  type        = string
}

variable "size" {
  description = "The unique slug that identifies the type of Droplet"
  type        = string
  default     = "s-1vcpu-1gb"
}

variable "region" {
  description = "The region to start the Droplet in"
  type        = string
  default     = "sfo3"
}

variable "image" {
  description = "The Droplet image ID or slug"
  type        = string
  default     = "ubuntu-22-04-x64"
}

variable "ssh_keys" {
  description = "A list of SSH key IDs or fingerprints to enable for the Droplet"
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  description = "The ID of the VPC where the Droplet will be located"
  type        = string
  default     = null
}

variable "tags" {
  description = "A list of tag names to be applied to the Droplet"
  type        = list(string)
  default     = []
}

variable "enable_backups" {
  description = "Boolean controlling if backups are enabled"
  type        = bool
  default     = false
}

variable "enable_ipv6" {
  description = "Boolean controlling if IPv6 is enabled"
  type        = bool
  default     = false
}

variable "user_data" {
  description = "A string of the desired User Data for the Droplet"
  type        = string
  default     = null
} 