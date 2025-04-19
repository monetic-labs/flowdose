# DNS Setup for FlowDose Staging Environment

To properly configure your staging environment, you need to set up the following DNS records:

## Required DNS Records

| Type | Hostname | Value | TTL |
|------|----------|-------|-----|
| A | staging.flowdose.xyz | 137.184.224.115 | 3600 |
| A | api-staging.flowdose.xyz | 134.199.223.159 | 3600 |
| A | admin-staging.flowdose.xyz | 134.199.223.159 | 3600 |

## Setting up in DigitalOcean DNS

1. Go to the DigitalOcean control panel
2. Navigate to Networking → Domains
3. Select your domain (flowdose.xyz)
4. Add the A records as specified above

## Verifying DNS Propagation

After adding the DNS records, you can verify they are properly propagated using:

```bash
dig staging.flowdose.xyz
dig api-staging.flowdose.xyz
dig admin-staging.flowdose.xyz
```

## Setting up SSL Certificates

Once DNS is configured and propagated, you can set up SSL certificates on each server:

### Backend Server (handles both API and Admin)

```bash
ssh root@134.199.223.159
certbot --nginx -d api-staging.flowdose.xyz -d admin-staging.flowdose.xyz
```

### Storefront Server

```bash
ssh root@137.184.224.115
certbot --nginx -d staging.flowdose.xyz
```

Follow the prompts to complete the SSL certificate setup.

## Testing

After DNS and SSL are configured, verify that your domains are accessible:

- https://staging.flowdose.xyz - Should show the storefront
- https://api-staging.flowdose.xyz - Should respond with API responses
- https://admin-staging.flowdose.xyz - Should redirect to the Medusa admin panel 