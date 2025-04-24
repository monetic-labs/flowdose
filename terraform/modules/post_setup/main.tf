variable "backend_ip" {
  description = "The IP address of the backend server"
  type        = string
}

variable "storefront_ip" {
  description = "The IP address of the storefront server"
  type        = string
}

variable "environment" {
  description = "The environment (staging or production)"
  type        = string
}

variable "ssh_user" {
  description = "SSH user for remote execution"
  type        = string
  default     = "root"
}

variable "ssh_private_key" {
  description = "SSH private key for remote execution"
  type        = string
  sensitive   = true
}

# Backend server setup
resource "null_resource" "setup_backend_server" {
  triggers = {
    backend_ip = var.backend_ip
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.backend_ip
    private_key = var.ssh_private_key
  }

  # Create directory structure
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /var/www/flowdose/backend",
      "mkdir -p /var/log/flowdose",
      "apt-get update",
      "apt-get install -y nginx git nodejs npm",
      "npm install -g pm2",
      "pm2 startup",
      "systemctl enable nginx"
    ]
  }

  # Configure Nginx for Backend
  provisioner "file" {
    content = templatefile("${path.module}/templates/nginx-backend.conf.tpl", {
      api_domain   = "api-${var.environment}.flowdose.xyz",
      admin_domain = "admin-${var.environment}.flowdose.xyz"
    })
    destination = "/etc/nginx/sites-available/flowdose-backend"
  }

  # Enable the Nginx configuration
  provisioner "remote-exec" {
    inline = [
      "ln -sf /etc/nginx/sites-available/flowdose-backend /etc/nginx/sites-enabled/",
      "rm -f /etc/nginx/sites-enabled/default",
      "nginx -t && systemctl restart nginx"
    ]
  }
}

# Storefront server setup
resource "null_resource" "setup_storefront_server" {
  triggers = {
    storefront_ip = var.storefront_ip
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.storefront_ip
    private_key = var.ssh_private_key
  }

  # Create directory structure
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /var/www/flowdose/storefront",
      "mkdir -p /var/log/flowdose",
      "apt-get update",
      "apt-get install -y nginx git nodejs npm",
      "npm install -g pm2",
      "pm2 startup",
      "systemctl enable nginx"
    ]
  }

  # Configure Nginx for Storefront
  provisioner "file" {
    content = templatefile("${path.module}/templates/nginx-storefront.conf.tpl", {
      domain = var.environment == "production" ? "flowdose.xyz" : "${var.environment}.flowdose.xyz"
    })
    destination = "/etc/nginx/sites-available/flowdose-storefront"
  }

  # Enable the Nginx configuration
  provisioner "remote-exec" {
    inline = [
      "ln -sf /etc/nginx/sites-available/flowdose-storefront /etc/nginx/sites-enabled/",
      "rm -f /etc/nginx/sites-enabled/default",
      "nginx -t && systemctl restart nginx"
    ]
  }
} 