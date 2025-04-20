# FlowDose Terraform Variables Documentation

This document provides an overview of all variables used in the FlowDose Terraform configuration.

## Root Module Variables

These variables are defined in the root `variables.tf` file:

| Variable | Description | Type | Required | Default |
|----------|-------------|------|----------|---------|
| `do_token` | DigitalOcean API token | string | Yes | - |
| `region` | DigitalOcean region | string | No | `"sfo3"` |
| `spaces_region` | DigitalOcean Spaces region | string | No | `"sfo3"` |
| `environment` | Environment (staging or production) | string | No | `"staging"` |

## Droplet Module Variables

These variables are used in the Droplet module:

| Variable | Description | Type | Required | Default |
|----------|-------------|------|----------|---------|
| `name` | The Droplet name | string | Yes | - |
| `size` | The unique slug that identifies the type of Droplet | string | No | `"s-1vcpu-1gb"` |
| `region` | The region to start the Droplet in | string | No | `"sfo3"` |
| `image` | The Droplet image ID or slug | string | No | `"ubuntu-22-04-x64"` |
| `ssh_keys` | A list of SSH key IDs or fingerprints | list(string) | No | `[]` |
| `vpc_id` | The ID of the VPC where the Droplet will be located | string | No | `null` |
| `tags` | A list of tag names to be applied to the Droplet | list(string) | No | `[]` |
| `enable_backups` | Boolean controlling if backups are enabled | bool | No | `false` |
| `enable_ipv6` | Boolean controlling if IPv6 is enabled | bool | No | `false` |
| `user_data` | A string of the desired User Data for the Droplet | string | No | `null` |

## Database Module Variables

These variables are used in the Database module:

| Variable | Description | Type | Required | Default |
|----------|-------------|------|----------|---------|
| `name` | The name of the database cluster | string | Yes | - |
| `engine` | Database engine (pg, mysql, redis, mongodb) | string | No | `"pg"` |
| `version` | Engine version | string | No | `"15"` |
| `size` | Database droplet size | string | No | `"db-s-1vcpu-1gb"` |
| `region` | The region to start the database in | string | No | `"sfo3"` |
| `node_count` | Number of nodes in the cluster | number | No | `1` |
| `tags` | A list of tag names to be applied to the database cluster | list(string) | No | `[]` |
| `vpc_id` | The ID of the VPC where the database will be located | string | No | `null` |
| `maintenance_day` | The day of the maintenance window | string | No | `"sunday"` |
| `maintenance_hour` | The hour of the maintenance window (UTC) | string | No | `"02:00:00"` |
| `databases` | List of database names to create | list(string) | No | `[]` |
| `database_users` | List of database user names to create | list(string) | No | `[]` |
| `allowed_ips` | List of IP addresses allowed to connect to the database | list(string) | No | `[]` |
| `allowed_droplet_ids` | List of Droplet IDs allowed to connect to the database | list(string) | No | `[]` |

## Redis Module Variables

These variables are used in the Redis module:

| Variable | Description | Type | Required | Default |
|----------|-------------|------|----------|---------|
| `name` | The name of the Redis cluster | string | Yes | - |
| `version` | Redis engine version | string | No | `"7"` |
| `size` | Database droplet size | string | No | `"db-s-1vcpu-1gb"` |
| `region` | The region to start the Redis cluster in | string | No | `"sfo3"` |
| `node_count` | Number of nodes in the cluster | number | No | `1` |
| `tags` | A list of tag names to be applied to the Redis cluster | list(string) | No | `[]` |
| `vpc_id` | The ID of the VPC where the Redis cluster will be located | string | No | `null` |
| `maintenance_day` | The day of the maintenance window | string | No | `"sunday"` |
| `maintenance_hour` | The hour of the maintenance window (UTC) | string | No | `"02:00:00"` |
| `allowed_ips` | List of IP addresses allowed to connect to the Redis cluster | list(string) | No | `[]` |
| `allowed_droplet_ids` | List of Droplet IDs allowed to connect to the Redis cluster | list(string) | No | `[]` |

## Spaces Module Variables

These variables are used in the Spaces module:

| Variable | Description | Type | Required | Default |
|----------|-------------|------|----------|---------|
| `name` | The name of the Spaces bucket | string | Yes | - |
| `region` | The region where the bucket resides | string | No | `"sfo3"` |
| `acl` | Canned ACL applied on bucket creation (private or public-read) | string | No | `"private"` |
| `force_destroy` | Allow deletion of non-empty bucket | bool | No | `false` |
| `enable_versioning` | Enable versioning for the Spaces bucket | bool | No | `false` |
| `cors_rules` | List of CORS rules | list(object) | No | `[]` |
| `lifecycle_rules` | List of lifecycle rules | list(object) | No | `[]` |
| `enable_cdn` | Enable CDN for the Spaces bucket | bool | No | `false` |
| `cdn_ttl` | The TTL for the CDN cache | number | No | `3600` |
| `cdn_custom_domain` | The custom domain for the CDN endpoint | string | No | `null` |

## Environment Configuration Module Variables

These variables are used in the Environment Configuration module:

| Variable | Description | Type | Required | Default |
|----------|-------------|------|----------|---------|
| `environment` | The environment (staging, production) | string | Yes | - |
| `backend_droplet_id` | The ID of the backend droplet | string | No | `""` |
| `backend_droplet_ip` | The IP address of the backend droplet | string | No | `""` |
| `storefront_droplet_id` | The ID of the storefront droplet | string | No | `""` |
| `storefront_droplet_ip` | The IP address of the storefront droplet | string | No | `""` |
| `database_url` | PostgreSQL database URL | string | Yes | - |
| `redis_url` | Redis URL | string | Yes | - |
| `admin_email` | Admin user email | string | No | `"admin@flowdose.xyz"` |
| `admin_password` | Admin user password | string | Yes | - |
| `resend_api_key` | Resend API key | string | Yes | - |
| `resend_from` | Email address to send from | string | No | `"no-reply@flowdose.xyz"` |
| `jwt_secret` | JWT secret for authentication | string | Yes | - |
| `cookie_secret` | Cookie secret for sessions | string | Yes | - |
| `revalidate_secret` | Secret for revalidating Next.js cache | string | Yes | - |
| `spaces_endpoint` | DigitalOcean Spaces endpoint | string | No | `"sfo3.digitaloceanspaces.com"` |
| `spaces_region` | DigitalOcean Spaces region | string | No | `"sfo3"` |
| `spaces_bucket` | DigitalOcean Spaces bucket name | string | Yes | - |
| `spaces_access_key` | DigitalOcean Spaces access key | string | Yes | - |
| `spaces_secret_key` | DigitalOcean Spaces secret key | string | Yes | - |
| `medusa_publishable_key` | Medusa publishable API key | string | Yes | - |
| `default_region` | Default region for store | string | No | `"US"` |
| `google_analytics_id` | Google Analytics ID | string | No | `""` |
| `ssh_private_key_path` | Path to SSH private key for server access | string | Yes | - |

## Deployment Module Variables

These variables are used in the Deployment module:

| Variable | Description | Type | Required | Default |
|----------|-------------|------|----------|---------|
| `node_env` | The Node environment | string | No | `"production"` |
| `backend_droplet_id` | The ID of the backend droplet | string | No | `""` |
| `backend_droplet_ip` | The IP address of the backend droplet | string | No | `""` |
| `backend_app_dir` | Directory where the backend app is located on the server | string | No | `""` |
| `backend_env_upload_id` | ID of the backend environment upload resource | string | No | `""` |
| `force_deploy_backend` | Force backend deployment even if environment hasn't changed | bool | No | `false` |
| `storefront_droplet_id` | The ID of the storefront droplet | string | No | `""` |
| `storefront_droplet_ip` | The IP address of the storefront droplet | string | No | `""` |
| `storefront_app_dir` | Directory where the storefront app is located on the server | string | No | `""` |
| `frontend_env_upload_id` | ID of the frontend environment upload resource | string | No | `""` |
| `force_deploy_storefront` | Force storefront deployment even if environment hasn't changed | bool | No | `false` |
| `ssh_private_key_path` | Path to SSH private key for server access | string | Yes | - | 