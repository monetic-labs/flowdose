locals {
  generated_dir = "${path.module}/../../generated"
}

# Ensure the generated directory exists
resource "null_resource" "create_generated_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.generated_dir}"
  }
}

# Create backend environment file
resource "local_file" "backend_env" {
  depends_on = [null_resource.create_generated_dir]
  
  content = templatefile("${path.module}/../../templates/backend.env.tpl", {
    # Core settings
    node_env = var.environment

    # Database settings
    database_url = var.database_url
    db_username  = var.db_username
    db_password  = var.db_password
    db_host      = var.db_host
    db_port      = var.db_port
    db_database  = var.db_database

    # Redis settings
    redis_url = var.redis_url

    # Admin settings
    admin_email    = var.admin_email
    admin_password = var.admin_password

    # Email settings
    resend_from = var.resend_from
    resend_key  = var.resend_api_key

    # Security settings
    jwt_secret    = var.jwt_secret
    cookie_secret = var.cookie_secret

    # Storage settings
    storage_endpoint   = var.spaces_endpoint
    storage_bucket     = var.spaces_bucket
    storage_access_key = var.spaces_access_key
    storage_secret_key = var.spaces_secret_key
    spaces_region      = var.spaces_region

    # Environment and URLs
    environment = var.environment
    admin_cors  = "https://admin-${var.environment}.flowdose.xyz"
    store_cors  = "https://${var.environment}.flowdose.xyz"
    auth_cors   = "https://admin-${var.environment}.flowdose.xyz,https://${var.environment}.flowdose.xyz"
  })
  filename = "${local.generated_dir}/.env.${var.environment}.backend"
}

# Create storefront environment file
resource "local_file" "frontend_env" {
  depends_on = [null_resource.create_generated_dir]
  
  content = templatefile("${path.module}/../../templates/storefront.env.tpl", {
    # API settings
    backend_url     = "https://api-${var.environment}.flowdose.xyz"
    publishable_key = var.medusa_publishable_key

    # URL settings
    base_url = "https://${var.environment == "production" ? "" : "${var.environment}."}flowdose.xyz"

    # Region settings
    default_region = var.default_region

    # Security settings
    revalidate_secret = var.revalidate_secret

    # Feature flags
    search_enabled = var.search_enabled

    # Analytics
    google_analytics_id = var.google_analytics_id

    # Environment
    node_env = var.environment
  })
  filename = "${local.generated_dir}/.env.${var.environment}.frontend"
} 