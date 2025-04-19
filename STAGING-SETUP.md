# FlowDose Staging Environment Setup

This document outlines the staging environment setup for FlowDose using DigitalOcean and GitHub Actions.

## Infrastructure

The staging environment consists of:

1. **Droplets:**
   - `staging-flowdose-backend` (2 vCPUs, 2GB RAM)
   - `staging-flowdose-storefront` (2 vCPUs, 2GB RAM)

2. **Managed Databases:**
   - `postgres-flowdose-staging` (PostgreSQL 15)
   - `redis-flowdose-staging` (Redis 7)

3. **Spaces:**
   - `staging-flowdose-bucket` for file storage
   - Spaces access keys required for configuration

## Initial Server Setup

For each droplet:

1. **Update and install dependencies:**
   ```bash
   apt update && apt upgrade -y
   apt install -y curl git nginx build-essential
   ```

2. **Install Node.js and PM2:**
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
   apt install -y nodejs
   npm install -g pm2
   ```

3. **Set up Corepack:**
   ```bash
   corepack enable
   ```

4. **Create app directory structure:**
   ```bash
   mkdir -p /home/username/app/scripts
   chown -R username:username /home/username/app
   ```

5. **Configure Nginx as reverse proxy:**
   Create `/etc/nginx/sites-available/flowdose` with appropriate configuration
   and enable with `ln -s /etc/nginx/sites-available/flowdose /etc/nginx/sites-enabled/`

6. **Set up SSL with Let's Encrypt:**
   ```bash
   apt install certbot python3-certbot-nginx
   certbot --nginx -d domain.com
   ```

## GitHub Setup

1. **Add these secrets to your GitHub repository:**
   - `STAGING_SSH_PRIVATE_KEY`: SSH private key for server access
   - `STAGING_SSH_USER`: Username for SSH login
   - `STAGING_BACKEND_HOST`: Hostname/IP of backend droplet
   - `STAGING_STOREFRONT_HOST`: Hostname/IP of storefront droplet

2. **Create a staging branch:**
   ```bash
   git checkout -b staging
   git push -u origin staging
   ```

## Environment Configuration

1. **Backend (.env.staging):**
   - Update with actual database and Redis connection strings
   - Add Spaces access keys for file storage
   - Configure MeiliSearch for the backend droplet

2. **Storefront (.env.staging):**
   - Update backend URL to point to the staging backend
   - After backend deployment, create a publishable API key in the admin panel
   - Add the publishable key to this file

## Project Structure

The deployment scripts are organized as follows:

```
flowdose/
├── .github/
│   └── workflows/
│       └── staging.yml         # GitHub Actions workflow for staging
├── backend/
│   ├── scripts/
│   │   └── deploy.sh           # Backend deployment script
│   └── .env.staging            # Backend environment variables
└── storefront/
    ├── scripts/
    │   └── deploy.sh           # Storefront deployment script
    └── .env.staging            # Storefront environment variables
```

## Deployment

Push to the staging branch to trigger automatic deployment:

```bash
git checkout staging
git merge main  # or another source branch
git push
```

The GitHub Actions workflow will:
1. Deploy the backend to the backend droplet
2. Deploy the storefront to the storefront droplet
3. Run migrations, build applications, and restart services

## Manual Steps After First Deployment

1. Access the Medusa admin at `https://admin-staging.flowdose.xyz`
2. Create a publishable API key for the storefront
3. Update `NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY` in the storefront's .env.staging file
4. Redeploy the storefront

## Debugging

- Check logs with `pm2 logs [service-name]`
- Check service status with `pm2 status`
- Nginx logs at `/var/log/nginx/access.log` and `/var/log/nginx/error.log` 