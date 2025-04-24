# Nginx configuration for Medusa Backend API

# API Server Block
server {
    listen 80;
    server_name ${api_domain};

    access_log /var/log/flowdose/api_access.log;
    error_log /var/log/flowdose/api_error.log;

    location / {
        proxy_pass http://localhost:9000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Large file uploads
    client_max_body_size 50M;
}

# Admin Panel Server Block
server {
    listen 80;
    server_name ${admin_domain};

    access_log /var/log/flowdose/admin_access.log;
    error_log /var/log/flowdose/admin_error.log;

    location / {
        proxy_pass http://localhost:7001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Large file uploads for admin
    client_max_body_size 50M;
} 