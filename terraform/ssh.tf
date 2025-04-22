# Create a new SSH key in DigitalOcean from the SSH public key provided by CI/CD
resource "digitalocean_ssh_key" "terraform_key" {
  count      = var.ssh_public_key != "" ? 1 : 0
  name       = "terraform-${var.environment}-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
  public_key = var.ssh_public_key
}

# Create an admin SSH key for persistent access if provided
resource "digitalocean_ssh_key" "admin_key" {
  count      = var.admin_ssh_public_key != "" ? 1 : 0
  name       = "admin-${var.environment}-key"
  public_key = var.admin_ssh_public_key
}

# Create a local variable to handle the SSH key list
locals {
  # Combine existing SSH key IDs with the new keys if they exist
  terraform_key_ids = var.ssh_public_key != "" ? [digitalocean_ssh_key.terraform_key[0].id] : []
  admin_key_ids     = var.admin_ssh_public_key != "" ? [digitalocean_ssh_key.admin_key[0].id] : []
  
  # Final list of all SSH keys to use
  ssh_keys = concat(var.ssh_key_ids, local.terraform_key_ids, local.admin_key_ids)
} 