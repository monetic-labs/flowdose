# FlowDose Infrastructure Testing Plan

This document outlines the testing procedures for verifying that the FlowDose infrastructure has been properly deployed and is functioning correctly.

## Infrastructure Verification Tests

### 1. Droplet Connectivity Tests

| Test | Description | Command/Method | Expected Result |
|------|-------------|----------------|-----------------|
| SSH Access - Backend | Verify SSH access to backend server | `ssh -i ~/.ssh/key root@BACKEND_IP` | Successful connection |
| SSH Access - Storefront | Verify SSH access to storefront server | `ssh -i ~/.ssh/key root@STOREFRONT_IP` | Successful connection |
| Public HTTP - Backend | Verify API is accessible | `curl -I https://api-{env}.flowdose.xyz` | HTTP 200 response |
| Public HTTP - Admin | Verify admin is accessible | `curl -I https://admin-{env}.flowdose.xyz` | HTTP 200 response |
| Public HTTP - Storefront | Verify storefront is accessible | `curl -I https://{env}.flowdose.xyz` | HTTP 200 response |

### 2. Database Tests

| Test | Description | Command/Method | Expected Result |
|------|-------------|----------------|-----------------|
| Database Connectivity | Verify backend can connect to database | Check logs: `pm2 logs medusa-backend` | No database connection errors |
| Database Initialization | Verify tables are created | Log into backend and check schema | Tables exist and are populated |
| Database Permissions | Verify correct permissions | Attempt database operations from backend | Operations succeed |

### 3. Redis Tests

| Test | Description | Command/Method | Expected Result |
|------|-------------|----------------|-----------------|
| Redis Connectivity | Verify backend can connect to Redis | Check logs: `pm2 logs medusa-backend` | No Redis connection errors |
| Redis Functionality | Verify Redis is functioning | Use Redis CLI on backend to set/get values | Operations succeed |

### 4. Object Storage Tests

| Test | Description | Command/Method | Expected Result |
|------|-------------|----------------|-----------------|
| Spaces Access | Verify backend can access Spaces | Upload an image through admin | Upload succeeds |
| Public Access | Verify public access to uploaded files | Access uploaded file URL | File is accessible |
| CDN (if enabled) | Verify CDN is serving files | Access file through CDN URL | File is served through CDN |

## Application Verification Tests

### 1. Backend Application Tests

| Test | Description | Expected Result |
|------|-------------|-----------------|
| Admin Login | Log in to admin panel | Successful login |
| API Health | Check API health endpoint | Response indicates healthy status |
| Create Product | Create a test product | Product is created successfully |
| Generate API Key | Generate a publishable API key | Key is generated successfully |

### 2. Storefront Application Tests

| Test | Description | Expected Result |
|------|-------------|-----------------|
| Load Homepage | Visit storefront homepage | Page loads with products |
| Search Function | Search for a product | Search results display correctly |
| Product Page | View a product page | Product details display correctly |
| Add to Cart | Add a product to cart | Product is added to cart |
| Checkout Flow | Begin checkout process | Checkout flow functions correctly |

## Environment Variables Verification

### 1. Backend Environment Variables

| Test | Description | Command/Method | Expected Result |
|------|-------------|----------------|-----------------|
| Env File Exists | Check if .env file exists | `ls -la /home/root/app/.env` | File exists |
| Variables Loaded | Verify environment variables are loaded | Check through application logs | No missing variable errors |
| Sensitive Variables | Verify sensitive variables are properly escaped | Check value rendering in logs/errors | No escaping issues in error messages |

### 2. Storefront Environment Variables

| Test | Description | Command/Method | Expected Result |
|------|-------------|----------------|-----------------|
| Env File Exists | Check if .env file exists | `ls -la /home/root/app/.env` | File exists |
| Variables Loaded | Verify environment variables are loaded | Check through application logs | No missing variable errors |
| API Connection | Verify storefront can connect to API | Visit storefront and check network requests | Successful API requests |

## Rollback Procedures

If any tests fail, follow these rollback procedures:

### Infrastructure Rollback

1. Capture the current state:
```bash
terraform state pull > terraform.tfstate.backup
```

2. Rollback to previous version:
```bash
terraform apply -var-file=terraform.tfvars -var-file=secrets.tfvars -target=MODULE.RESOURCE
```

### Application Rollback

1. SSH into the affected server:
```bash
ssh -i ~/.ssh/key root@SERVER_IP
```

2. Check application logs:
```bash
pm2 logs APP_NAME
```

3. Restart the application:
```bash
pm2 restart APP_NAME
```

4. If necessary, restore from backup:
```bash
# Database backup restore
psql -h HOSTNAME -U USERNAME -d DATABASE -f backup.sql

# File backup restore (if needed)
aws s3 cp s3://backup-bucket/backup.tar.gz /tmp/
tar -xzf /tmp/backup.tar.gz -C /home/root/app
```

## Testing Automation Scripts

### Infrastructure Test Script

Create a script called `test_infrastructure.sh` for basic connectivity tests:

```bash
#!/bin/bash
set -e

ENV=${1:-staging}
BACKEND_IP=$(terraform output -raw backend_droplet_ip)
STOREFRONT_IP=$(terraform output -raw storefront_droplet_ip)

echo "Testing backend connectivity..."
curl -sI "https://api-${ENV}.flowdose.xyz" | grep "HTTP"

echo "Testing admin connectivity..."
curl -sI "https://admin-${ENV}.flowdose.xyz" | grep "HTTP"

echo "Testing storefront connectivity..."
curl -sI "https://${ENV}.flowdose.xyz" | grep "HTTP"

echo "All connectivity tests passed!"
```

### Environment Variables Test Script

Create a script called `test_env_vars.sh` for checking environment variables:

```bash
#!/bin/bash
set -e

SSH_KEY=${1:-~/.ssh/id_rsa}
BACKEND_IP=$(terraform output -raw backend_droplet_ip)
STOREFRONT_IP=$(terraform output -raw storefront_droplet_ip)

echo "Checking backend environment variables..."
ssh -i $SSH_KEY root@$BACKEND_IP "grep -v '^#' /home/root/app/.env | wc -l"

echo "Checking storefront environment variables..."
ssh -i $SSH_KEY root@$STOREFRONT_IP "grep -v '^#' /home/root/app/.env | wc -l"

echo "Environment variable check complete!"
```

## Conclusion

Following this testing plan ensures that your infrastructure is properly deployed and configured. Perform these tests after every major deployment to ensure environment stability. 