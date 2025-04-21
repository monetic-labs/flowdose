# Create a new SSH key in DigitalOcean from the SSH public key provided by CI/CD
resource "digitalocean_ssh_key" "terraform_key" {
  count      = var.ssh_public_key != "" ? 1 : 0
  name       = "terraform-${var.environment}-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
  public_key = var.ssh_public_key
}

# Create a local variable to handle the SSH key list
locals {
  # Combine existing SSH key IDs with the new key if it exists
  ssh_keys = var.ssh_public_key != "" ? concat(var.ssh_key_ids, [digitalocean_ssh_key.terraform_key[0].id]) : var.ssh_key_ids
} 