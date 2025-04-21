# FlowDose Terraform Configuration

locals {
  common_tags = {
    Project     = "FlowDose"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  is_production = var.environment == "production"

  # Domain names
  api_domain        = "api-${var.environment}.flowdose.xyz"
  admin_domain      = "admin-${var.environment}.flowdose.xyz"
  storefront_domain = local.is_production ? "flowdose.xyz" : "${var.environment}.flowdose.xyz"
}

# Backend Server
module "backend_droplet" {
  source = "./modules/droplet"

  name   = "flowdose-backend-${var.environment}"
  size   = var.backend_droplet_size
  region = var.region
  image  = var.droplet_image

  ssh_keys = local.ssh_keys

  tags = concat(["backend", "flowdose", var.environment], var.additional_tags)
}

# Storefront Server
module "storefront_droplet" {
  source = "./modules/droplet"

  name   = "flowdose-storefront-${var.environment}"
  size   = var.storefront_droplet_size
  region = var.region
  image  = var.droplet_image

  ssh_keys = local.ssh_keys

  tags = concat(["storefront", "flowdose", var.environment], var.additional_tags)
}

# PostgreSQL Database
module "postgres_db" {
  source = "./modules/database"

  name           = "postgres-flowdose-${var.environment}"
  engine         = "pg"
  engine_version = var.postgres_version
  size           = var.db_size
  region         = var.region
  node_count     = local.is_production ? 1 : 1

  tags = concat(["database", "flowdose", var.environment], var.additional_tags)

  databases      = ["flowdose_${var.environment}"]
  database_users = ["flowdose_admin"]

  allowed_droplet_ids = [
    module.backend_droplet.id
  ]
}

# Redis Cache
module "redis_db" {
  source = "./modules/redis"

  name           = "redis-flowdose-${var.environment}"
  engine_version = var.redis_version
  size           = var.redis_size
  region         = var.region
  node_count     = local.is_production ? 1 : 1

  tags = concat(["redis", "flowdose", var.environment], var.additional_tags)

  allowed_droplet_ids = [
    module.backend_droplet.id
  ]
}

# Media Storage
module "media_storage" {
  source = "./modules/spaces"

  name   = "${var.environment}-flowdose-bucket"
  region = var.spaces_region
  acl    = "private"

  enable_versioning = true

  # CORS configuration for media uploads
  cors_rules = [{
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE"]
    allowed_origins = [
      "https://${local.api_domain}",
      "https://${local.admin_domain}",
      "https://${local.storefront_domain}"
    ]
    max_age_seconds = 3600
  }]

  # Lifecycle rules
  lifecycle_rules = [{
    enabled = true
    expiration = {
      days = 365 * 10 # Keep for 10 years
    }
  }]
}

# DNS Configuration
module "dns" {
  source = "./modules/dns"

  environment   = var.environment
  is_production = local.is_production
  backend_ip    = module.backend_droplet.ipv4_address
  storefront_ip = module.storefront_droplet.ipv4_address
}

# SSL Configuration
module "ssl" {
  source = "./modules/ssl"

  # Server IPs
  backend_ip    = module.backend_droplet.ipv4_address
  storefront_ip = module.storefront_droplet.ipv4_address

  # Domain names
  api_domain        = local.api_domain
  admin_domain      = local.admin_domain
  storefront_domain = local.storefront_domain

  # Admin contact
  admin_email = var.admin_email

  # SSH access
  ssh_private_key_path = var.ssh_private_key_path

  # Ensure this runs after DNS is configured
  depends_on = [module.dns]
}
