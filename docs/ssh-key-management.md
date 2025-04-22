# SSH Key Management for FlowDose Deployment

This document explains how SSH keys are managed in the FlowDose deployment process.

## Overview

The FlowDose CI/CD pipeline uses a dual-key approach for SSH access to droplets:

1. **Ephemeral Deployment Key**: Generated during each CI/CD run for automation purposes
2. **Persistent Admin Key**: Stored in GitHub secrets for manual access and troubleshooting

This approach ensures both automated deployments and manual administration can work reliably.

## How It Works

### Key Generation and Registration

1. The GitHub workflow generates a new SSH key pair for each deployment run
2. Both the ephemeral deployment key and the admin key (from GitHub secrets) are registered with DigitalOcean
3. Both keys are assigned to new droplets during creation
4. The workflow uses the ephemeral key for all deployment operations

### Manual Access

To access the servers manually after deployment:

1. Use the private key corresponding to the public key stored in `ADMIN_SSH_PUBLIC_KEY` GitHub secret
2. SSH into the server using: `ssh -i /path/to/your/admin_key root@SERVER_IP`

## Setup Instructions

### Adding Your Admin Key to GitHub Secrets

1. Generate an SSH key pair on your local machine if you don't already have one:
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/flowdose_admin
   ```

2. Add the **public key** to your GitHub repository secrets:
   - Go to your repository → Settings → Secrets and variables → Actions
   - Create a new repository secret named `ADMIN_SSH_PUBLIC_KEY`
   - Paste the contents of your public key (from `~/.ssh/flowdose_admin.pub`)

3. Keep the private key (`~/.ssh/flowdose_admin`) secure on your machine for SSH access

### Connecting to Servers

To connect to servers after deployment:

```bash
# Get server IPs from the workflow output or DigitalOcean dashboard
ssh -i ~/.ssh/flowdose_admin root@BACKEND_IP
ssh -i ~/.ssh/flowdose_admin root@STOREFRONT_IP
```

## Best Practices

1. **Never** commit private keys to the repository
2. Rotate admin keys periodically for enhanced security
3. Use passphrase-protected keys when possible
4. Consider using jump/bastion hosts for production environments
5. Implement IP-based restrictions for SSH access when applicable

## Troubleshooting

If you're unable to SSH into a server:

1. Verify the admin public key is properly set in GitHub secrets
2. Check that the workflow completed successfully
3. Ensure you're using the correct private key that matches the public key in GitHub secrets
4. Verify the server IP address is correct
5. Check for firewall rules that might be blocking SSH access (port 22)

## Advanced Configuration

For more complex setups, consider:

1. Using multiple admin keys for different team members
2. Implementing SSH Certificate Authority (CA) for more granular access control
3. Setting up VPN access for enhanced security 