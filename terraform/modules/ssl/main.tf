# Disabled SSL module to prevent SSH connection attempts
# We'll handle SSL certificates manually or through a separate process

locals {
  # Placeholders to avoid errors when this module is referenced
  backend_ssl_id = "disabled-backend-ssl"
  storefront_ssl_id = "disabled-storefront-ssl"
}

# SSL Certificate Management for FlowDose
# This module handles SSL certificate provisioning through Let's Encrypt

# Wait for DNS propagation before attempting to provision certificates
resource "null_resource" "wait_for_dns_backend" {
  provisioner "local-exec" {
    command = "echo 'Waiting for DNS propagation (60 seconds)...' && sleep 60"
  }
}

# Backend SSL Certificate Provisioning
resource "null_resource" "backend_ssl" {
  # Trigger on IP changes or domain changes
  triggers = {
    backend_ip = var.backend_ip
    api_domain = var.api_domain
    admin_domain = var.admin_domain
  }

  # Install Certbot and issue certificates for backend domains
  provisioner "remote-exec" {
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",
      "if ! command -v certbot &> /dev/null; then",
      "  apt-get update",
      "  apt-get install -y certbot python3-certbot-nginx",
      "fi",
      "certbot --nginx --non-interactive --agree-tos -m ${var.admin_email} -d ${var.api_domain} -d ${var.admin_domain}",
      "systemctl reload nginx"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = var.backend_ip
    }
  }

  depends_on = [null_resource.wait_for_dns_backend]
}

# Storefront SSL Certificate Provisioning
resource "null_resource" "storefront_ssl" {
  # Trigger on IP changes or domain changes
  triggers = {
    storefront_ip = var.storefront_ip
    storefront_domain = var.storefront_domain
  }

  # Install Certbot and issue certificates for storefront domain
  provisioner "remote-exec" {
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",
      "if ! command -v certbot &> /dev/null; then",
      "  apt-get update",
      "  apt-get install -y certbot python3-certbot-nginx",
      "fi",
      "certbot --nginx --non-interactive --agree-tos -m ${var.admin_email} -d ${var.storefront_domain}",
      "systemctl reload nginx"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = var.storefront_ip
    }
  }

  depends_on = [null_resource.wait_for_dns_backend]
}

# Add an automated renewal setup
resource "null_resource" "setup_renewal" {
  # Run this for both servers
  count = 2

  # Only trigger when the SSL cert has been changed
  triggers = {
    ssl_changes = count.index == 0 ? null_resource.backend_ssl.id : null_resource.storefront_ssl.id
  }

  # Set up auto-renewal cron job
  provisioner "remote-exec" {
    inline = [
      "echo '0 3 * * * /usr/bin/certbot renew --quiet' | tee -a /etc/crontab"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = count.index == 0 ? var.backend_ip : var.storefront_ip
    }
  }

  depends_on = [null_resource.backend_ssl, null_resource.storefront_ssl]
} 