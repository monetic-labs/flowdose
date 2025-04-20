# SSL Certificate Management for FlowDose
# This module sets up Let's Encrypt certificates on the servers

# Backend server certificates
resource "null_resource" "backend_ssl" {
  # Only run when backend IP or DNS changes
  triggers = {
    backend_ip   = var.backend_ip
    api_domain   = var.api_domain
    admin_domain = var.admin_domain
  }

  # Install Certbot and request certificates
  provisioner "remote-exec" {
    inline = [
      "# Install Certbot if not already installed",
      "apt-get update",
      "apt-get install -y certbot python3-certbot-nginx",

      "# Configure Nginx to use SSL and obtain certificates",
      "certbot --nginx --non-interactive --agree-tos -m ${var.admin_email} -d ${var.api_domain} -d ${var.admin_domain}",

      "# Make sure auto-renewal is enabled",
      "systemctl enable certbot.timer",
      "systemctl start certbot.timer",

      "# Test renewal process",
      "certbot renew --dry-run"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = var.backend_ip
      timeout     = "5m"
    }
  }
}

# Storefront server certificates
resource "null_resource" "storefront_ssl" {
  # Only run when storefront IP or DNS changes
  triggers = {
    storefront_ip     = var.storefront_ip
    storefront_domain = var.storefront_domain
  }

  # Install Certbot and request certificates
  provisioner "remote-exec" {
    inline = [
      "# Install Certbot if not already installed",
      "apt-get update",
      "apt-get install -y certbot python3-certbot-nginx",

      "# Configure Nginx to use SSL and obtain certificates",
      "certbot --nginx --non-interactive --agree-tos -m ${var.admin_email} -d ${var.storefront_domain}",

      "# Make sure auto-renewal is enabled",
      "systemctl enable certbot.timer",
      "systemctl start certbot.timer",

      "# Test renewal process",
      "certbot renew --dry-run"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = var.storefront_ip
      timeout     = "5m"
    }
  }
} 