# DNS Management for FlowDose
# This module manages DNS records for the flowdose.xyz domain

# Domain registration
resource "digitalocean_domain" "flowdose" {
  name = var.is_production ? "flowdose.xyz" : "${var.environment}.flowdose.xyz"
}

# A Records
resource "digitalocean_record" "backend_api" {
  domain = digitalocean_domain.flowdose.name
  type   = "A"
  name   = "api-${var.environment}"
  value  = var.backend_ip
  ttl    = 3600
}

resource "digitalocean_record" "backend_admin" {
  domain = digitalocean_domain.flowdose.name
  type   = "A"
  name   = "admin-${var.environment}"
  value  = var.backend_ip
  ttl    = 3600
}

resource "digitalocean_record" "storefront" {
  domain = digitalocean_domain.flowdose.name
  type   = "A"
  name   = var.is_production ? "@" : var.environment
  value  = var.storefront_ip
  ttl    = 3600
}

# Email records (preserved from existing configuration)
resource "digitalocean_record" "mx_notifications" {
  count    = var.is_production ? 1 : 0
  domain   = digitalocean_domain.flowdose.name
  type     = "MX"
  name     = "send.notifications"
  value    = "feedback-smtp.us-east-1.amazonses.com."
  priority = 10
  ttl      = 14400
}

resource "digitalocean_record" "spf_record" {
  count  = var.is_production ? 1 : 0
  domain = digitalocean_domain.flowdose.name
  type   = "TXT"
  name   = "send.notifications"
  value  = "v=spf1 include:amazonses.com ~all"
  ttl    = 3600
}

resource "digitalocean_record" "dkim_record" {
  count  = var.is_production ? 1 : 0
  domain = digitalocean_domain.flowdose.name
  type   = "TXT"
  name   = "resend._domainkey.notifications"
  value  = "p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC/ETInbetWI5/mvIFhYv32nipKhZTm4ZYBky/4Rnm3rNKmRKc49p65vv85b1CkxEOKN7aOs1vr8erkmP1NKKHzJAn6svNlgYCL65CUosivXFcG9OSsNLtm03mgbmczfsmIhiig9BYXxCJaIvwtlJSNuC8IakTjqegzN4W/UGobmwIDAQAB"
  ttl    = 3600
}

resource "digitalocean_record" "dmarc_record" {
  count  = var.is_production ? 1 : 0
  domain = digitalocean_domain.flowdose.name
  type   = "TXT"
  name   = "_dmarc"
  value  = "v=DMARC1; p=none;"
  ttl    = 3600
} 