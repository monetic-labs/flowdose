# FlowDose Infrastructure Plan

## Current Infrastructure Overview

FlowDose is a B2B ecommerce platform built with MedusaJS, consisting of:

- **Backend Service**: Node.js server with MedusaJS framework
- **Admin Interface**: Built into the backend service at `/app` endpoint
- **Storefront**: Next.js frontend application

The platform currently uses DigitalOcean for hosting with:
- Droplets for application hosting
- Managed PostgreSQL database
- Managed Redis instance
- Spaces for object storage
- GitHub Actions for CI/CD

## Infrastructure Migration to Terraform

### Goals

1. **Infrastructure as Code (IaC)**: Define all infrastructure components in version-controlled Terraform files
2. **Consistent Environments**: Ensure parity between development, staging, and production
3. **Secure Secrets Management**: Properly handle sensitive values without shell escaping issues
4. **Automated Deployments**: Streamline deployment processes with proper environment configuration
5. **Scalability**: Design for future growth and performance needs

### Infrastructure Components

#### 1. Compute Resources (Droplets)

```hcl
module "backend_droplet" {
  source  = "./modules/droplet"
  name    = "backend-${var.environment}"
  region  = var.region
  size    = var.backend_droplet_size
  ssh_keys = var.ssh_keys
  tags    = ["backend", var.environment]
}

module "storefront_droplet" {
  source  = "./modules/droplet"
  name    = "storefront-${var.environment}"
  region  = var.region
  size    = var.storefront_droplet_size
  ssh_keys = var.ssh_keys
  tags    = ["storefront", var.environment]
}
```

#### 2. Database Resources

```hcl
resource "digitalocean_database_cluster" "postgres" {
  name       = "postgres-${var.environment}"
  engine     = "pg"
  version    = "15"
  size       = var.db_size
  region     = var.region
  node_count = var.environment == "production" ? 2 : 1
}

resource "digitalocean_database_db" "medusa_db" {
  cluster_id = digitalocean_database_cluster.postgres.id
  name       = "flowdose_${var.environment}"
}
```

#### 3. Redis Instance

```hcl
resource "digitalocean_database_cluster" "redis" {
  name       = "redis-${var.environment}"
  engine     = "redis"
  version    = "6"
  size       = var.redis_size
  region     = var.region
  node_count = var.environment == "production" ? 2 : 1
}
```

#### 4. Object Storage (Spaces)

```hcl
resource "digitalocean_spaces_bucket" "media_bucket" {
  name   = "${var.environment}-flowdose-bucket"
  region = var.spaces_region
  acl    = "private"
}

resource "digitalocean_spaces_bucket_policy" "media_policy" {
  bucket = digitalocean_spaces_bucket.media_bucket.name
  region = digitalocean_spaces_bucket.media_bucket.region
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["s3:GetObject"],
      "Resource": ["arn:aws:s3:::${var.environment}-flowdose-bucket/*"]
    }]
  })
}
```

### Environment Configuration Management

#### Backend Service Configuration

The backend service requires multiple environment variables, many containing special characters that create shell escaping issues in the current setup.

##### Proposed Solution:

1. **Environment File Generation**:

```hcl
resource "local_file" "backend_env" {
  content = templatefile("${path.module}/templates/backend.env.tpl", {
    node_env           = var.environment
    database_url       = digitalocean_database_cluster.postgres.uri
    redis_url          = digitalocean_database_cluster.redis.uri
    admin_email        = var.admin_email
    admin_password     = var.admin_password
    resend_from        = var.resend_from
    resend_key         = var.resend_api_key
    jwt_secret         = random_string.jwt_secret.result
    cookie_secret      = random_string.cookie_secret.result
    minio_endpoint     = "${var.spaces_region}.digitaloceanspaces.com"
    minio_access_key   = var.spaces_access_key
    minio_secret_key   = var.spaces_secret_key
    minio_bucket       = digitalocean_spaces_bucket.media_bucket.name
    admin_cors         = "https://admin-${var.environment}.flowdose.xyz"
    store_cors         = "https://${var.environment}.flowdose.xyz"
    auth_cors          = "https://admin-${var.environment}.flowdose.xyz,https://${var.environment}.flowdose.xyz"
  })
  filename = "${path.module}/generated/.env.${var.environment}"
}
```

2. **Secure File Transfer**:

```hcl
resource "null_resource" "upload_backend_env" {
  depends_on = [local_file.backend_env]

  provisioner "file" {
    source      = "${path.module}/generated/.env.${var.environment}"
    destination = "/home/root/app/.env"

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = module.backend_droplet.ipv4_address
    }
  }
}
```

#### Storefront Configuration

```hcl
resource "local_file" "frontend_env" {
  content = templatefile("${path.module}/templates/frontend.env.tpl", {
    backend_url     = "https://api-${var.environment}.flowdose.xyz"
    publishable_key = var.medusa_publishable_key
    base_url        = "https://${var.environment}.flowdose.xyz"
    default_region  = var.default_region
    revalidate_secret = random_string.revalidate_secret.result
    search_enabled  = true
  })
  filename = "${path.module}/generated/.env.${var.environment}.frontend"
}

resource "null_resource" "upload_frontend_env" {
  depends_on = [local_file.frontend_env]

  provisioner "file" {
    source      = "${path.module}/generated/.env.${var.environment}.frontend"
    destination = "/home/root/app/.env"

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = module.storefront_droplet.ipv4_address
    }
  }
}
```

### Deployment Process

#### Backend Deployment

1. **Build Process**:
   - Create a Terraform module to handle the backend build and deployment
   - Generate a properly formatted `.env` file
   - Upload the file to the target server
   - Execute deployment commands via SSH or use a more robust solution like Ansible

```hcl
resource "null_resource" "deploy_backend" {
  depends_on = [null_resource.upload_backend_env]

  provisioner "remote-exec" {
    inline = [
      "cd /home/root/app",
      "yarn install",
      "yarn build",
      "pm2 stop medusa-backend || true",
      "pm2 start --name medusa-backend 'cd .medusa/server && yarn run start'"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = module.backend_droplet.ipv4_address
    }
  }
}
```

2. **Publishable API Key Management**:
   - Create a process to generate and retrieve the publishable API key after deployment
   - Store this key in Terraform state or a secure parameter store
   - Use this key during the storefront deployment

#### Storefront Deployment

```hcl
resource "null_resource" "deploy_storefront" {
  depends_on = [null_resource.upload_frontend_env]

  provisioner "remote-exec" {
    inline = [
      "cd /home/root/app",
      "yarn install",
      "yarn build",
      "pm2 stop nextjs-storefront || true",
      "pm2 start --name nextjs-storefront 'yarn start'"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = module.storefront_droplet.ipv4_address
    }
  }
}
```

### DNS Configuration

```hcl
resource "digitalocean_domain" "flowdose" {
  name = "${var.environment == "production" ? "" : "${var.environment}."}flowdose.xyz"
}

resource "digitalocean_record" "backend" {
  domain = digitalocean_domain.flowdose.name
  type   = "A"
  name   = "api-${var.environment}"
  value  = module.backend_droplet.ipv4_address
}

resource "digitalocean_record" "admin" {
  domain = digitalocean_domain.flowdose.name
  type   = "A"
  name   = "admin-${var.environment}"
  value  = module.backend_droplet.ipv4_address
}

resource "digitalocean_record" "storefront" {
  domain = digitalocean_domain.flowdose.name
  type   = "A"
  name   = "@"
  value  = module.storefront_droplet.ipv4_address
}
```

### CI/CD Integration

#### GitHub Actions Workflow

1. **Terraform Plan Stage**:
   - Run on pull requests to preview infrastructure changes
   
2. **Terraform Apply Stage**:
   - Run on merge to main/staging branches
   - Apply infrastructure changes
   - Output necessary values for deployment

3. **Deployment Stage**:
   - Use Terraform outputs to deploy applications
   - Run database migrations
   - Verify deployment success

```yaml
name: Terraform CI/CD

on:
  push:
    branches: [main, staging]
  pull_request:
    branches: [main, staging]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        
      - name: Terraform Init
        run: terraform init
        
      - name: Terraform Plan
        if: github.event_name == 'pull_request'
        run: terraform plan
        
      - name: Terraform Apply
        if: github.event_name == 'push'
        run: terraform apply -auto-approve
```

## Implementation Phases

### Phase 1: Terraform Setup (1-2 weeks)
- Set up Terraform project structure
- Create base modules for DigitalOcean resources
- Implement state management (using remote state in DigitalOcean Spaces)
- Document infrastructure variables and requirements

### Phase 2: Infrastructure as Code (2-3 weeks)
- Implement all infrastructure components in Terraform
- Create environment templates
- Build environment variable management system
- Develop deployment scripts

### Phase 3: CI/CD Integration (1-2 weeks)
- Integrate Terraform with GitHub Actions
- Set up separate workflows for staging and production
- Create backup and disaster recovery processes
- Implement monitoring and alerting

### Phase 4: Migration (1 week)
- Migrate staging environment to Terraform-managed infrastructure
- Test and validate all components
- Document operational procedures

### Phase 5: Production Migration (1 week)
- Migrate production environment to Terraform-managed infrastructure
- Perform final testing and validation
- Complete documentation

## Benefits of This Approach

1. **Elimination of Environment Variable Issues**:
   - Properly escaped environment variables in generated files
   - No more shell escaping problems

2. **Consistency Across Environments**:
   - Same infrastructure and configuration process for all environments
   - Reduced configuration drift

3. **Security Improvements**:
   - Better secrets management
   - Reduced manual handling of sensitive values

4. **Operational Efficiency**:
   - Automated infrastructure provisioning
   - Faster and more reliable deployments
   - Disaster recovery capabilities

5. **Documentation and Visibility**:
   - Infrastructure defined as code provides built-in documentation
   - Changes tracked in version control

## Resource Requirements

- **Engineering Time**: 5-8 weeks for full implementation
- **Tools**: Terraform, GitHub Actions, SSH keys, DigitalOcean API tokens
- **Knowledge**: Terraform, DigitalOcean provider, MedusaJS deployment requirements

## Conclusion

Migrating to a Terraform-based infrastructure approach will solve our current environment variable issues while providing numerous additional benefits. The upfront investment in setting up this infrastructure will pay dividends in reduced operational headaches, improved security, and more consistent deployments.

---

**Next Steps:**
1. Review and approve this infrastructure plan
2. Set up Terraform project structure and state management
3. Create base modules for DigitalOcean resources
4. Begin Phase 1 implementation
