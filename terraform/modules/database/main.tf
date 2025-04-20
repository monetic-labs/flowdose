resource "digitalocean_database_cluster" "this" {
  name       = var.name
  engine     = var.engine
  version    = var.engine_version
  size       = var.size
  region     = var.region
  node_count = var.node_count
  tags       = var.tags

  private_network_uuid = var.vpc_id

  # Maintenance window
  maintenance_window {
    day  = var.maintenance_day
    hour = var.maintenance_hour
  }
}

# Create a database within the cluster
resource "digitalocean_database_db" "database" {
  count      = length(var.databases)
  cluster_id = digitalocean_database_cluster.this.id
  name       = var.databases[count.index]
}

# Create database users
resource "digitalocean_database_user" "users" {
  count      = length(var.database_users)
  cluster_id = digitalocean_database_cluster.this.id
  name       = var.database_users[count.index]
}

# Firewall for the database cluster
resource "digitalocean_database_firewall" "firewall" {
  count      = length(var.allowed_ips) > 0 || length(var.allowed_droplet_ids) > 0 ? 1 : 0
  cluster_id = digitalocean_database_cluster.this.id

  # Allow connections from specified IPs
  dynamic "rule" {
    for_each = var.allowed_ips
    content {
      type  = "ip_addr"
      value = rule.value
    }
  }

  # Allow connections from specified droplets
  dynamic "rule" {
    for_each = var.allowed_droplet_ids
    content {
      type  = "droplet"
      value = rule.value
    }
  }
} 