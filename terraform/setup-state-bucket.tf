# This file is used to create the initial Terraform state bucket
# After running this once, you can comment out the resource and 
# uncomment the backend configuration in backend.tf

# Resource commented out because the bucket already exists
# resource "digitalocean_spaces_bucket" "terraform_state" {
#   name   = "flowdose-terraform-state"
#   region = var.spaces_region
#   acl    = "private"
#
#   versioning {
#     enabled = true
#   }
#
#   lifecycle_rule {
#     enabled = true
#
#     noncurrent_version_expiration {
#       days = 90
#     }
#   }
# } 