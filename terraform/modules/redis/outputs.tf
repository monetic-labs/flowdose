output "id" {
  description = "The ID of the Redis cluster"
  value       = digitalocean_database_cluster.redis.id
}

output "name" {
  description = "The name of the Redis cluster"
  value       = digitalocean_database_cluster.redis.name
}

output "host" {
  description = "The hostname of the Redis cluster"
  value       = digitalocean_database_cluster.redis.host
}

output "private_host" {
  description = "The private hostname of the Redis cluster"
  value       = digitalocean_database_cluster.redis.private_host
}

output "port" {
  description = "Network port that the Redis cluster is listening on"
  value       = digitalocean_database_cluster.redis.port
}

output "uri" {
  description = "The full URI for connecting to the Redis cluster"
  value       = digitalocean_database_cluster.redis.uri
  sensitive   = true
}

output "private_uri" {
  description = "The private URI for connecting to the Redis cluster"
  value       = digitalocean_database_cluster.redis.private_uri
  sensitive   = true
}

output "password" {
  description = "The password for the default user"
  value       = digitalocean_database_cluster.redis.password
  sensitive   = true
} 