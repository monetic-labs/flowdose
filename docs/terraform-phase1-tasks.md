# FlowDose Terraform Migration - Phase 1 Tasks

## 1. Initial Setup (2-3 days)

- [x] Create Terraform project structure
  - [x] Set up root module with `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`
  - [x] Create environment-specific directories (`staging`, `production`)
  - [x] Create shared modules directory

- [x] Configure Terraform state management
  - [x] Create DigitalOcean Space for Terraform state
  - [x] Configure backend configuration for remote state
  - [x] Set up state locking mechanism

- [x] Create `.gitignore` for Terraform files
  - [x] Exclude `.terraform` directories
  - [x] Exclude `.tfstate` files and backups
  - [x] Exclude sensitive variable files

## 2. Core Module Development (4-5 days)

- [x] Create DigitalOcean Droplet module
  - [x] Define size, region, and SSH key variables
  - [x] Configure networking and firewall settings
  - [x] Add tags for environment identification
  - [x] Create separate configurations for backend and storefront droplets

- [x] Create Database module
  - [x] Configure PostgreSQL cluster settings
  - [x] Set up database user and permissions
  - [x] Define backup policy

- [x] Create Redis module
  - [x] Configure Redis instance settings
  - [x] Set up firewall rules

- [x] Create Spaces (object storage) module
  - [x] Configure bucket settings and permissions
  - [x] Set up CDN if required

## 3. Monorepo Structure Management (2-3 days)

- [x] Define path handling for monorepo components
  - [x] Configure Terraform to reference correct `/backend` and `/storefront` paths
  - [x] Set up appropriate working directory configurations for remote commands

- [x] Create build process configuration
  - [x] Define backend build process in Terraform
  - [x] Define storefront build process in Terraform
  - [x] Configure handling of shared dependencies (if any)

- [x] Design file transfer strategy for monorepo
  - [x] Configure correct source paths for backend files
  - [x] Configure correct source paths for storefront files
  - [x] Define destination paths on respective droplets

## 4. Environment Configuration Management (3-4 days)

- [x] Create secure environment variable management system
  - [x] Design template files for `/backend` `.env` generation
  - [x] Design template files for `/storefront` `.env` generation
  - [x] Create scripts to securely generate environment files

- [x] Implement secret management
  - [x] Set up secure variables storage for sensitive values
  - [x] Configure sensitive variable handling in Terraform
  - [x] Create process for generating and rotating secrets
  - [x] Ensure backend service can access required secrets
  - [x] Ensure storefront can access its required environment variables

- [x] Create deployment configuration
  - [x] Define file transfer mechanism for environment files
  - [x] Create SSH execution scripts for deployment commands
  - [x] Configure proper escaping for special characters

## 5. Documentation and Testing (2-3 days)

- [x] Document infrastructure variables
  - [x] Create variables documentation for each module
  - [x] Document required environment variables for backend application
  - [x] Document required environment variables for storefront application
  - [x] Create setup guide for new environments

- [x] Create testing plan
  - [x] Define verification steps for infrastructure deployment
  - [x] Create test scripts for environment configuration
  - [x] Document rollback procedures
  - [x] Add specific tests for backend connectivity
  - [x] Add specific tests for storefront functionality

- [ ] Set up staging environment test
  - [ ] Create staging configuration
  - [ ] Test infrastructure deployment in isolation
  - [ ] Validate environment variable handling
  - [ ] Test backend and storefront communications

## 6. CI/CD Integration Planning (2-3 days)

- [x] Plan GitHub Actions integration
  - [x] Design workflow for Terraform plan/apply
  - [x] Configure secure handling of Terraform credentials
  - [x] Design integration between Terraform and deployment processes
  - [x] Define triggers for backend-only changes
  - [x] Define triggers for storefront-only changes
  - [x] Define triggers for full-stack changes

- [x] Create deployment scripts
  - [x] Design script for `/backend` deployment
  - [x] Design script for `/storefront` deployment
  - [x] Configure dependency handling between components
  - [x] Configure proper error handling and verification

## Next Steps After Phase 1

Once Phase 1 is complete, we'll have the foundation for managing our infrastructure as code. Next phases will involve:

- Implementing the full infrastructure in Terraform (Phase 2)
- Integrating with CI/CD (Phase 3)
- Migrating staging and production environments (Phases 4-5) 