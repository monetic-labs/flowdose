# Nginx configuration for Next.js Storefront

server {
    listen 80;
    server_name ${domain};

    access_log /var/log/flowdose/storefront_access.log;
    error_log /var/log/flowdose/storefront_error.log;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Next.js handles not found pages internally
        proxy_intercept_errors off;
    }

    # Static assets caching
    location /_next/static/ {
        proxy_pass http://localhost:8000/_next/static/;
        proxy_cache_valid 200 302 60m;
        proxy_cache_valid 404 1m;
        expires 1y;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    # Custom images and static files
    location /images/ {
        proxy_pass http://localhost:8000/images/;
        proxy_cache_valid 200 302 60m;
        proxy_cache_valid 404 1m;
        expires 7d;
        add_header Cache-Control "public, max-age=604800";
    }

    # Large file uploads
    client_max_body_size 50M;
} 