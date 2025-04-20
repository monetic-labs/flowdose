output "id" {
  description = "The ID of the database cluster"
  value       = digitalocean_database_cluster.this.id
}

output "name" {
  description = "The name of the database cluster"
  value       = digitalocean_database_cluster.this.name
}

output "host" {
  description = "The hostname of the database cluster"
  value       = digitalocean_database_cluster.this.host
}

output "private_host" {
  description = "The private hostname of the database cluster"
  value       = digitalocean_database_cluster.this.private_host
}

output "port" {
  description = "Network port that the database cluster is listening on"
  value       = digitalocean_database_cluster.this.port
}

output "uri" {
  description = "The full URI for connecting to the database cluster"
  value       = digitalocean_database_cluster.this.uri
  sensitive   = true
}

output "private_uri" {
  description = "The private URI for connecting to the database cluster"
  value       = digitalocean_database_cluster.this.private_uri
  sensitive   = true
}

output "database_names" {
  description = "The names of the databases in the cluster"
  value       = digitalocean_database_db.database[*].name
}

output "user_names" {
  description = "The names of the database users"
  value       = digitalocean_database_user.users[*].name
}

output "password" {
  description = "The password for the default user"
  value       = digitalocean_database_cluster.this.password
  sensitive   = true
} 