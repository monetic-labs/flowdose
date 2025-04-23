# Disabled SSL module to prevent SSH connection attempts
# We'll handle SSL certificates manually or through a separate process

locals {
  # Placeholders to avoid errors when this module is referenced
  backend_ssl_id = "disabled-backend-ssl"
  storefront_ssl_id = "disabled-storefront-ssl"
}

# SSL Certificate Management for FlowDose
# This module handles SSL certificate provisioning through Let's Encrypt

# First, wait longer for DNS propagation before attempting to provision certificates
resource "null_resource" "wait_for_dns_backend" {
  provisioner "local-exec" {
    command = "echo 'Waiting for DNS propagation (180 seconds)...' && sleep 180"
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

  # Install Certbot and issue certificates for backend domains with enhanced debugging
  provisioner "remote-exec" {
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",
      
      # Add debugging information
      "echo 'Starting SSL provisioning for ${var.api_domain} and ${var.admin_domain}'",
      "echo 'Server IP: ${var.backend_ip}'",
      
      # Install certbot if not already present
      "if ! command -v certbot &> /dev/null; then",
      "  echo 'Installing certbot...'",
      "  apt-get update",
      "  apt-get install -y certbot python3-certbot-nginx",
      "fi",
      
      # Verify DNS resolution locally to help troubleshoot
      "echo 'Verifying DNS resolution from server:'",
      "echo '${var.api_domain} resolves to:' $(dig +short ${var.api_domain} || echo 'Failed to resolve')",
      "echo '${var.admin_domain} resolves to:' $(dig +short ${var.admin_domain} || echo 'Failed to resolve')",
      
      # Test nginx configuration
      "echo 'Testing nginx configuration:'",
      "nginx -t || echo 'Nginx config test failed but continuing'",
      
      # Ensure port 80 is available for challenge
      "echo 'Checking if port 80 is open:'",
      "netstat -tuln | grep ':80 ' || echo 'Port 80 not listening - this may be normal'",
      
      # Try to use certbot staging first to avoid rate limits
      "echo 'Attempting to get certificates from staging server first...'",
      "certbot --staging --nginx --non-interactive --agree-tos -m ${var.admin_email} -d ${var.api_domain} -d ${var.admin_domain} || echo 'Staging certificate request failed, but proceeding with production attempt'",
      
      # Now try production with proper error handling
      "echo 'Attempting to get certificates from production server...'",
      "certbot --nginx --non-interactive --agree-tos -m ${var.admin_email} -d ${var.api_domain} -d ${var.admin_domain} || { echo 'Certificate request failed. Checking logs:'; journalctl -u certbot.service; exit 1; }",
      
      # Reload nginx if successful
      "systemctl reload nginx",
      "echo 'SSL certificates have been successfully provisioned!'"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = var.backend_ip
      # Add timeout settings
      timeout     = "10m"
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

  # Install Certbot and issue certificates for storefront domain with enhanced debugging
  provisioner "remote-exec" {
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",
      
      # Add debugging information
      "echo 'Starting SSL provisioning for ${var.storefront_domain}'",
      "echo 'Server IP: ${var.storefront_ip}'",
      
      # Install certbot if not already present
      "if ! command -v certbot &> /dev/null; then",
      "  echo 'Installing certbot...'",
      "  apt-get update",
      "  apt-get install -y certbot python3-certbot-nginx",
      "fi",
      
      # Verify DNS resolution locally to help troubleshoot
      "echo 'Verifying DNS resolution from server:'",
      "echo '${var.storefront_domain} resolves to:' $(dig +short ${var.storefront_domain} || echo 'Failed to resolve')",
      
      # Test nginx configuration
      "echo 'Testing nginx configuration:'",
      "nginx -t || echo 'Nginx config test failed but continuing'",
      
      # Ensure port 80 is available for challenge
      "echo 'Checking if port 80 is open:'",
      "netstat -tuln | grep ':80 ' || echo 'Port 80 not listening - this may be normal'",
      
      # Try to use certbot staging first to avoid rate limits
      "echo 'Attempting to get certificates from staging server first...'",
      "certbot --staging --nginx --non-interactive --agree-tos -m ${var.admin_email} -d ${var.storefront_domain} || echo 'Staging certificate request failed, but proceeding with production attempt'",
      
      # Now try production with proper error handling
      "echo 'Attempting to get certificates from production server...'",
      "certbot --nginx --non-interactive --agree-tos -m ${var.admin_email} -d ${var.storefront_domain} || { echo 'Certificate request failed. Checking logs:'; journalctl -u certbot.service; exit 1; }",
      
      # Reload nginx if successful
      "systemctl reload nginx",
      "echo 'SSL certificates have been successfully provisioned!'"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = var.storefront_ip
      # Add timeout settings
      timeout     = "10m"
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
      "echo '0 3 * * * /usr/bin/certbot renew --quiet' | tee -a /etc/crontab",
      "echo 'SSL certificate renewal has been configured'"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = count.index == 0 ? var.backend_ip : var.storefront_ip
      timeout     = "5m"
    }
  }

  depends_on = [null_resource.backend_ssl, null_resource.storefront_ssl]
} 