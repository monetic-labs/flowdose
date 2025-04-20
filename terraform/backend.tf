# This file contains the configuration for Terraform's state backend

terraform {
  backend "s3" {
    endpoint                    = "sfo3.digitaloceanspaces.com"
    region                      = "us-west-1" # Required but ignored for DigitalOcean Spaces
    bucket                      = "flowdose-state-storage"
    key                         = "terraform.tfstate"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
  }
}

# To initialize this backend, you need to:
# 1. Create the bucket manually or using a separate Terraform configuration
# 2. Uncomment the configuration above
# 3. Configure credentials using:
#    - AWS_ACCESS_KEY_ID (DO Spaces access key)
#    - AWS_SECRET_ACCESS_KEY (DO Spaces secret key)
# 4. Run: terraform init 