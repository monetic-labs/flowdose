# FlowDose Storefront Environment Variables (Next.js)

# API Configuration
NEXT_PUBLIC_API_URL=${backend_url}
NEXT_PUBLIC_MEDUSA_BACKEND_URL=${backend_url}
NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=${publishable_key}

# Alternative API naming (if used)
NEXT_PUBLIC_BACKEND_URL=${backend_url}
NEXT_PUBLIC_SERVER_URL=${backend_url}
API_BASE_URL=${backend_url}

# General Settings
NEXT_PUBLIC_SITE_NAME=FlowDose
NEXT_PUBLIC_SITE_URL=${base_url}
NEXT_PUBLIC_DEFAULT_REGION=${default_region}
NEXT_PUBLIC_COMPANY_NAME=FlowDose

# Cache and Revalidation
REVALIDATE_SECRET=${revalidate_secret}
NEXT_REVALIDATE_SECRET=${revalidate_secret}

# Features
NEXT_PUBLIC_SEARCH_ENABLED=${search_enabled}
NEXT_PUBLIC_ENABLE_SEARCH=${search_enabled}

# Analytics (optional)
${google_analytics_id == "" ? "# NEXT_PUBLIC_GA_TRACKING_ID=" : "NEXT_PUBLIC_GA_TRACKING_ID=${google_analytics_id}"}
${google_analytics_id == "" ? "# NEXT_PUBLIC_GOOGLE_ANALYTICS_ID=" : "NEXT_PUBLIC_GOOGLE_ANALYTICS_ID=${google_analytics_id}"}

# Development Settings
${node_env == "development" ? "NODE_TLS_REJECT_UNAUTHORIZED=0" : "# NODE_TLS_REJECT_UNAUTHORIZED=0"}

# Environment
NEXT_PUBLIC_ENV=${node_env}
NODE_ENV=${node_env}
