# Post-deployment configuration for FlowDose
# This file contains resources that depend on the core infrastructure being created

# Environment Configuration Module - Configuration Generation Only
module "env_config_generation" {
  source = "./modules/env_config_generation"

  environment = var.environment

  # Database connection
  database_url = module.postgres_db.uri
  redis_url    = module.redis_db.uri

  # Admin user
  admin_email    = var.admin_email
  admin_password = var.admin_password

  # Email service
  resend_api_key = var.resend_api_key
  resend_from    = var.resend_from

  # Security
  jwt_secret        = var.jwt_secret
  cookie_secret     = var.cookie_secret
  revalidate_secret = var.revalidate_secret

  # Spaces/S3
  spaces_endpoint   = "${var.spaces_region}.digitaloceanspaces.com"
  spaces_region     = var.spaces_region
  spaces_bucket     = module.media_storage.name
  spaces_access_key = var.spaces_access_key
  spaces_secret_key = var.spaces_secret_key

  # Medusa
  medusa_publishable_key = var.medusa_publishable_key

  # Region settings
  default_region = var.default_region

  # Analytics
  google_analytics_id = var.google_analytics_id

  depends_on = [
    module.postgres_db,
    module.redis_db,
    module.media_storage,
    module.backend_droplet,
    module.storefront_droplet
  ]
}

# Environment File Upload - Backend
/*
resource "null_resource" "upload_backend_env" {
  triggers = {
    droplet_id = module.backend_droplet.id
    # Using a simpler trigger that doesn't rely on file existence
    config_id  = module.env_config_generation.id
  }

  provisioner "file" {
    source      = module.env_config_generation.backend_env_path
    destination = "/home/root/app/.env"

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = module.backend_droplet.ipv4_address
    }
  }

  depends_on = [
    module.env_config_generation,
    module.backend_droplet
  ]
}
*/

# Use a local for the backend env upload ID since we've commented out the resource
locals {
  backend_env_upload_id = "disabled-backend-env-upload"
}

# Environment File Upload - Storefront
/*
resource "null_resource" "upload_frontend_env" {
  triggers = {
    droplet_id = module.storefront_droplet.id
    # Using a simpler trigger that doesn't rely on file existence
    config_id  = module.env_config_generation.id
  }

  provisioner "file" {
    source      = module.env_config_generation.frontend_env_path
    destination = "/home/root/app/.env"

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = module.storefront_droplet.ipv4_address
    }
  }

  depends_on = [
    module.env_config_generation,
    module.storefront_droplet
  ]
}
*/

# Use a local for the frontend env upload ID since we've commented out the resource
locals {
  frontend_env_upload_id = "disabled-frontend-env-upload"
}

# Deployment Module - Now only depends on the uploaded environment files
module "deployment" {
  source = "./modules/deployment"

  node_env = var.environment
  environment = var.environment

  # Backend deployment
  backend_droplet_id    = module.backend_droplet.id
  backend_droplet_ip    = module.backend_droplet.ipv4_address
  backend_env_upload_id = local.backend_env_upload_id
  force_deploy_backend  = var.force_deploy_backend

  # Storefront deployment
  storefront_droplet_id   = module.storefront_droplet.id
  storefront_droplet_ip   = module.storefront_droplet.ipv4_address
  frontend_env_upload_id  = local.frontend_env_upload_id
  force_deploy_storefront = var.force_deploy_storefront

  # SSH
  ssh_private_key_path = var.ssh_private_key_path

  # Remove dependencies on the env upload resources
  depends_on = [
    module.env_config_generation
  ]
} 