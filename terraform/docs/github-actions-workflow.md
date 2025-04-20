# GitHub Actions Workflow for Terraform

This document outlines the proposed GitHub Actions workflow for managing FlowDose infrastructure with Terraform.

## Workflow Design

We will use GitHub Actions to automate the Terraform workflow, including:

1. **Validation and linting** for all pull requests
2. **Plan generation** for visibility into changes
3. **Apply changes** to infrastructure upon merge to main branches
4. **Targeted deployment** for backend or storefront-specific changes

## Workflow Files

### 1. Terraform Validation Workflow

File: `.github/workflows/terraform-validate.yml`

```yaml
name: "Terraform Validation"

on:
  pull_request:
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-*.yml'

jobs:
  validate:
    name: "Terraform Validate"
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./terraform
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Init
        run: terraform init -backend=false

      - name: Terraform Validate
        run: terraform validate
```

### 2. Terraform Plan Workflow

File: `.github/workflows/terraform-plan.yml`

```yaml
name: "Terraform Plan"

on:
  pull_request:
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-*.yml'

jobs:
  plan:
    name: "Terraform Plan"
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./terraform
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.SPACES_ACCESS_KEY }}
          aws-secret-access-key: ${{ secrets.SPACES_SECRET_KEY }}
          aws-region: us-east-1

      - name: Terraform Init
        run: terraform init
        env:
          TF_CLI_ARGS_init: "-backend-config='access_key=${{ secrets.SPACES_ACCESS_KEY }}' -backend-config='secret_key=${{ secrets.SPACES_SECRET_KEY }}'"

      - name: Terraform Plan
        run: terraform plan -var-file=example.tfvars -var="do_token=${{ secrets.DO_API_TOKEN }}" -no-color
        continue-on-error: true
        id: plan

      - name: Add Plan Comment
        uses: actions/github-script@v6
        if: github.event_name == 'pull_request'
        env:
          PLAN: "${{ steps.plan.outputs.stdout }}"
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const output = `#### Terraform Plan 📝
            <details>
            <summary>Show Plan</summary>

            \`\`\`
            ${process.env.PLAN}
            \`\`\`

            </details>`;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            })
```

### 3. Terraform Apply Workflow

File: `.github/workflows/terraform-apply.yml`

```yaml
name: "Terraform Apply"

on:
  push:
    branches:
      - main
      - staging
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-*.yml'

jobs:
  apply:
    name: "Terraform Apply"
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./terraform
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.SPACES_ACCESS_KEY }}
          aws-secret-access-key: ${{ secrets.SPACES_SECRET_KEY }}
          aws-region: us-east-1

      - name: Terraform Init
        run: terraform init
        env:
          TF_CLI_ARGS_init: "-backend-config='access_key=${{ secrets.SPACES_ACCESS_KEY }}' -backend-config='secret_key=${{ secrets.SPACES_SECRET_KEY }}'"

      - name: Determine Environment
        id: vars
        run: |
          if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "environment=production" >> $GITHUB_OUTPUT
          else
            echo "environment=staging" >> $GITHUB_OUTPUT
          fi

      - name: Terraform Apply
        run: |
          terraform apply -auto-approve \
            -var-file=example.tfvars \
            -var="do_token=${{ secrets.DO_API_TOKEN }}" \
            -var="environment=${{ steps.vars.outputs.environment }}" \
            -var="admin_email=${{ secrets.ADMIN_EMAIL }}" \
            -var="admin_password=${{ secrets.ADMIN_PASSWORD }}" \
            -var="jwt_secret=${{ secrets.JWT_SECRET }}" \
            -var="cookie_secret=${{ secrets.COOKIE_SECRET }}" \
            -var="resend_api_key=${{ secrets.RESEND_API_KEY }}" \
            -var="spaces_access_key=${{ secrets.SPACES_ACCESS_KEY }}" \
            -var="spaces_secret_key=${{ secrets.SPACES_SECRET_KEY }}" \
            -var="ssh_private_key_path=${{ secrets.SSH_PRIVATE_KEY_PATH }}"
```

### 4. Backend-only Deployment Workflow

File: `.github/workflows/backend-deploy.yml`

```yaml
name: "Backend Deployment"

on:
  push:
    branches:
      - main
      - staging
    paths:
      - 'backend/**'
      - '!backend/README.md'
      - '!backend/docs/**'

jobs:
  deploy:
    name: "Deploy Backend"
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./terraform
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.SPACES_ACCESS_KEY }}
          aws-secret-access-key: ${{ secrets.SPACES_SECRET_KEY }}
          aws-region: us-east-1

      - name: Terraform Init
        run: terraform init
        env:
          TF_CLI_ARGS_init: "-backend-config='access_key=${{ secrets.SPACES_ACCESS_KEY }}' -backend-config='secret_key=${{ secrets.SPACES_SECRET_KEY }}'"

      - name: Determine Environment
        id: vars
        run: |
          if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "environment=production" >> $GITHUB_OUTPUT
          else
            echo "environment=staging" >> $GITHUB_OUTPUT
          fi

      - name: Force Backend Deployment
        run: |
          terraform apply -auto-approve \
            -var-file=example.tfvars \
            -var="do_token=${{ secrets.DO_API_TOKEN }}" \
            -var="environment=${{ steps.vars.outputs.environment }}" \
            -var="admin_email=${{ secrets.ADMIN_EMAIL }}" \
            -var="admin_password=${{ secrets.ADMIN_PASSWORD }}" \
            -var="jwt_secret=${{ secrets.JWT_SECRET }}" \
            -var="cookie_secret=${{ secrets.COOKIE_SECRET }}" \
            -var="resend_api_key=${{ secrets.RESEND_API_KEY }}" \
            -var="spaces_access_key=${{ secrets.SPACES_ACCESS_KEY }}" \
            -var="spaces_secret_key=${{ secrets.SPACES_SECRET_KEY }}" \
            -var="ssh_private_key_path=${{ secrets.SSH_PRIVATE_KEY_PATH }}" \
            -var="force_deploy_backend=true"
```

### 5. Storefront-only Deployment Workflow

File: `.github/workflows/storefront-deploy.yml`

```yaml
name: "Storefront Deployment"

on:
  push:
    branches:
      - main
      - staging
    paths:
      - 'storefront/**'
      - '!storefront/README.md'
      - '!storefront/docs/**'

jobs:
  deploy:
    name: "Deploy Storefront"
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./terraform
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.SPACES_ACCESS_KEY }}
          aws-secret-access-key: ${{ secrets.SPACES_SECRET_KEY }}
          aws-region: us-east-1

      - name: Terraform Init
        run: terraform init
        env:
          TF_CLI_ARGS_init: "-backend-config='access_key=${{ secrets.SPACES_ACCESS_KEY }}' -backend-config='secret_key=${{ secrets.SPACES_SECRET_KEY }}'"

      - name: Determine Environment
        id: vars
        run: |
          if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "environment=production" >> $GITHUB_OUTPUT
          else
            echo "environment=staging" >> $GITHUB_OUTPUT
          fi

      - name: Force Storefront Deployment
        run: |
          terraform apply -auto-approve \
            -var-file=example.tfvars \
            -var="do_token=${{ secrets.DO_API_TOKEN }}" \
            -var="environment=${{ steps.vars.outputs.environment }}" \
            -var="admin_email=${{ secrets.ADMIN_EMAIL }}" \
            -var="admin_password=${{ secrets.ADMIN_PASSWORD }}" \
            -var="jwt_secret=${{ secrets.JWT_SECRET }}" \
            -var="cookie_secret=${{ secrets.COOKIE_SECRET }}" \
            -var="resend_api_key=${{ secrets.RESEND_API_KEY }}" \
            -var="spaces_access_key=${{ secrets.SPACES_ACCESS_KEY }}" \
            -var="spaces_secret_key=${{ secrets.SPACES_SECRET_KEY }}" \
            -var="ssh_private_key_path=${{ secrets.SSH_PRIVATE_KEY_PATH }}" \
            -var="force_deploy_storefront=true"
```

## GitHub Secrets

The following secrets need to be configured in your GitHub repository:

| Secret Name | Description |
|-------------|-------------|
| `DO_API_TOKEN` | DigitalOcean API Token |
| `SPACES_ACCESS_KEY` | Spaces Access Key |
| `SPACES_SECRET_KEY` | Spaces Secret Key |
| `ADMIN_EMAIL` | Admin user email |
| `ADMIN_PASSWORD` | Admin user password |
| `JWT_SECRET` | Secret for JWT tokens |
| `COOKIE_SECRET` | Secret for cookies |
| `RESEND_API_KEY` | Resend.com API key |
| `SSH_PRIVATE_KEY_PATH` | Path to SSH key (or actual key content) |

## Workflow Security Considerations

1. **Secret Management**: All sensitive values are stored as GitHub Secrets
2. **Access Control**: Limit workflow execution to specific branches and paths
3. **Plan Visibility**: Show plans on PRs but never expose sensitive values
4. **Approval Process**: Consider adding approval workflow for production deployments

## Implementation Steps

1. Create the workflow files in the `.github/workflows/` directory
2. Configure the required secrets in GitHub repository settings
3. Set up proper branch protection rules (require passing checks)
4. Test the workflows with a small change (e.g., documentation update)
5. Monitor initial deployments carefully 