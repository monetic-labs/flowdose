resource "digitalocean_droplet" "this" {
  name       = var.name
  size       = var.size
  region     = var.region
  image      = var.image
  ssh_keys   = var.ssh_keys
  vpc_uuid   = var.vpc_id
  tags       = var.tags
  monitoring = true

  # Optional backups
  backups = var.enable_backups

  # Optional IPv6
  ipv6 = var.enable_ipv6

  # Use cloud-init user data if provided
  user_data = var.user_data

  # Ensure recreation instead of in-place update for most changes
  lifecycle {
    create_before_destroy = true
  }
} 