# FlowDose Environment Setup Guide

This guide walks through the process of setting up a new environment using our Terraform configuration.

## Prerequisites

Before you begin, ensure you have the following:

1. **DigitalOcean API Token** with write access to your account
2. **SSH key** registered with DigitalOcean
3. **Terraform CLI** installed locally (version 1.0.0+)
4. **AWS CLI** installed locally (for Spaces S3 compatibility)

## Setup Steps

### 1. Prepare your configuration

1. Clone the configuration from `terraform.tfvars.example`:

```bash
cd terraform
cp example.tfvars terraform.tfvars
```

2. Edit `terraform.tfvars` with your actual values:

```
do_token         = "your_digitalocean_api_token"
environment      = "staging"  # or "production"
region           = "sfo3"
spaces_region    = "sfo3"
ssh_key_ids      = ["12345678"]  # Your actual SSH key IDs
```

3. For sensitive values, use a separate `secrets.tfvars` file (which will be ignored by git):

```bash
# Create a secrets file
touch secrets.tfvars

# Add sensitive values
cat <<EOF > secrets.tfvars
admin_email        = "admin@yourdomain.com"
admin_password     = "your_secure_password"
jwt_secret         = "your_jwt_secret"
cookie_secret      = "your_cookie_secret"
resend_api_key     = "your_resend_api_key"
spaces_access_key  = "your_spaces_access_key"
spaces_secret_key  = "your_spaces_secret_key"
ssh_private_key_path = "/path/to/your/private_key"
EOF
```

### 2. Initialize Terraform

Set up the remote state bucket:

```bash
# Set your DigitalOcean Spaces credentials
export AWS_ACCESS_KEY_ID=your_spaces_access_key
export AWS_SECRET_ACCESS_KEY=your_spaces_secret_key

# Initialize Terraform
terraform init

# Create just the state bucket first
terraform apply -target=digitalocean_spaces_bucket.terraform_state
```

Once the state bucket is created, uncomment the backend configuration in `backend.tf` and reinitialize:

```bash
terraform init
```

### 3. Deploy the environment

Now you can deploy the full environment:

```bash
# Show the planned changes
terraform plan -var-file=terraform.tfvars -var-file=secrets.tfvars

# Apply the changes
terraform apply -var-file=terraform.tfvars -var-file=secrets.tfvars
```

### 4. Access your environment

After successful deployment, Terraform will output URLs for your environment:

- Backend API: https://api-{environment}.flowdose.xyz
- Admin Panel: https://admin-{environment}.flowdose.xyz
- Storefront: https://{environment}.flowdose.xyz (or https://flowdose.xyz for production)

You can log in to the admin panel with the credentials specified in your `secrets.tfvars` file.

## Environment Maintenance

### Updating the environment

To update your environment after making changes:

```bash
# Update with the latest code
git pull

# Plan and apply changes
terraform plan -var-file=terraform.tfvars -var-file=secrets.tfvars
terraform apply -var-file=terraform.tfvars -var-file=secrets.tfvars
```

### Redeploying applications

To force redeployment of the applications without infrastructure changes:

```bash
# Force backend redeployment
terraform apply -var-file=terraform.tfvars -var-file=secrets.tfvars -var force_deploy_backend=true

# Force storefront redeployment
terraform apply -var-file=terraform.tfvars -var-file=secrets.tfvars -var force_deploy_storefront=true
```

### Managing environment variables

To update environment variables:

1. Update your secret values in `secrets.tfvars`
2. Run Terraform apply to regenerate and upload the environment files:

```bash
terraform apply -var-file=terraform.tfvars -var-file=secrets.tfvars
```

## Troubleshooting

### SSH access

If you need direct SSH access to debug issues:

```bash
# SSH to backend server
ssh -i /path/to/private_key root@$(terraform output -raw backend_droplet_ip)

# SSH to storefront server
ssh -i /path/to/private_key root@$(terraform output -raw storefront_droplet_ip)
```

### Checking logs

To check application logs:

```bash
# Backend logs
ssh -i /path/to/private_key root@$(terraform output -raw backend_droplet_ip) "pm2 logs medusa-backend"

# Storefront logs
ssh -i /path/to/private_key root@$(terraform output -raw storefront_droplet_ip) "pm2 logs nextjs-storefront"
```

### Common issues

1. **Environment files not updated**: Manually verify the `.env` files on the servers
2. **Deployment fails**: Check the PM2 logs for errors
3. **Cannot connect to database**: Verify firewall rules allow connection from the droplets 