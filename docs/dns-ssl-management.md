# DNS and SSL Management for FlowDose

This document explains how DNS and SSL certificates are managed in the FlowDose deployment process.

## Overview

FlowDose uses Terraform to automate both DNS management and SSL certificate provisioning:

1. **DNS Records**: Automatically updated when new server infrastructure is provisioned
2. **SSL Certificates**: Automatically provisioned using Let's Encrypt after DNS propagation

This approach ensures that when new infrastructure is deployed (with new IP addresses), both DNS records and SSL certificates are updated accordingly.

## How DNS Management Works

### DNS Record Management

1. The Terraform DNS module creates or updates A records for:
   - `api-staging.flowdose.xyz` → Backend server IP
   - `admin-staging.flowdose.xyz` → Backend server IP 
   - `staging.flowdose.xyz` → Storefront server IP

2. When new droplets are created with new IP addresses, the DNS records are automatically updated to point to the new IPs.

3. A 3600-second TTL (Time-To-Live) is set, meaning DNS changes propagate globally within approximately one hour.

### DNS Propagation

- DNS changes take time to propagate worldwide (up to an hour with the current TTL)
- The SSL provisioning includes a 60-second wait to allow DNS to begin propagation
- For faster testing, you can manually modify your local hosts file to point the domains to the new IPs

## How SSL Management Works

### SSL Certificate Provisioning 

1. After DNS records are updated and a wait period passes, the SSL module:
   - Connects to both servers via SSH
   - Installs Certbot and its Nginx plugin if not already present
   - Requests Let's Encrypt certificates for all domains
   - Configures Nginx to use these certificates
   - Sets up automatic renewal

2. Certificates are provisioned using the backend and storefront servers' Nginx configurations.

3. Auto-renewal is configured via a cron job that runs daily at 3 AM.

### SSL Triggers

The SSL certificates are automatically re-provisioned when:
- Server IP addresses change
- Domain names change

## Troubleshooting

### DNS Issues

If domains are not resolving to the correct IP addresses:

1. Check the output of the Terraform deployment for the correct IPs
2. Verify DNS records using a tool like `dig` or `nslookup`:
   ```bash
   dig api-staging.flowdose.xyz
   ```
3. Remember that DNS changes can take up to an hour to propagate globally
4. For immediate testing, add entries to your local hosts file

### SSL Certificate Issues

If SSL certificates are not working correctly:

1. Verify Nginx is running on the servers:
   ```bash
   ssh root@SERVER_IP "systemctl status nginx"
   ```

2. Check Certbot certificates:
   ```bash
   ssh root@SERVER_IP "certbot certificates"
   ```

3. Manually trigger certificate renewal:
   ```bash
   ssh root@SERVER_IP "certbot renew --dry-run"
   ```

4. Check Nginx SSL configuration:
   ```bash
   ssh root@SERVER_IP "nginx -t"
   ```

## Best Practices

1. **DNS TTL**: Consider lowering the TTL before planned infrastructure changes for faster propagation
2. **Rate Limits**: Be aware of Let's Encrypt's rate limits (5 failures per hour, 50 certificates per registered domain per week)
3. **Backup Certificates**: Consider backing up `/etc/letsencrypt` for critical deployments
4. **Testing**: Set up a staging environment for testing infrastructure changes before production deployment

## Advanced Configuration

For more complex setups, consider:

1. **DNS Providers**: If not using DigitalOcean DNS, integrate with other providers via appropriate Terraform providers
2. **CDN Integration**: Add a CDN like Cloudflare in front of your infrastructure
3. **Wildcard Certificates**: Use wildcard certificates for multiple subdomains
4. **Managed Certificate Services**: Consider using DigitalOcean's managed certificates instead of Let's Encrypt for production 