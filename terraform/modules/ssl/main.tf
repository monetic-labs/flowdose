# Disabled SSL module to prevent SSH connection attempts
# We'll handle SSL certificates manually or through a separate process

locals {
  # Placeholders to avoid errors when this module is referenced
  backend_ssl_id = "disabled-backend-ssl"
  storefront_ssl_id = "disabled-storefront-ssl"
} 