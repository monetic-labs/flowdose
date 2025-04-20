output "id" {
  description = "The ID of the Droplet"
  value       = digitalocean_droplet.this.id
}

output "name" {
  description = "The name of the Droplet"
  value       = digitalocean_droplet.this.name
}

output "ipv4_address" {
  description = "The IPv4 address of the Droplet"
  value       = digitalocean_droplet.this.ipv4_address
}

output "ipv4_address_private" {
  description = "The private IPv4 address of the Droplet"
  value       = digitalocean_droplet.this.ipv4_address_private
}

output "ipv6_address" {
  description = "The IPv6 address of the Droplet"
  value       = digitalocean_droplet.this.ipv6_address
}

output "region" {
  description = "The region of the Droplet"
  value       = digitalocean_droplet.this.region
}

output "size" {
  description = "The size of the Droplet"
  value       = digitalocean_droplet.this.size
} 