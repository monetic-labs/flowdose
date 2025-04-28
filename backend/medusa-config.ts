import { QUOTE_MODULE } from "./src/modules/quote";
import { APPROVAL_MODULE } from "./src/modules/approval";
import { COMPANY_MODULE } from "./src/modules/company";
import { loadEnv, defineConfig, Modules } from "@medusajs/framework/utils";

loadEnv(process.env.NODE_ENV!, process.cwd());

const REDIS_URL = process.env.REDIS_URL || "redis://localhost:6380";

module.exports = defineConfig({
  projectConfig: {
    databaseUrl: process.env.DATABASE_URL,
    redisUrl: REDIS_URL,
    http: {
      storeCors: process.env.STORE_CORS!,
      adminCors: process.env.ADMIN_CORS!,
      authCors: process.env.AUTH_CORS!,
      jwtSecret: process.env.JWT_SECRET || "supersecret",
      cookieSecret: process.env.COOKIE_SECRET || "supersecret",
    },
    workerMode: process.env.MEDUSA_WORKER_MODE as "shared" | "worker" | "server",
  },
  admin: {
    disable: process.env.DISABLE_MEDUSA_ADMIN === "true",
  },
  plugins: [
    {
      resolve: "medusa-plugin-meilisearch",
      options: {
        config: {
          host: process.env.MEILISEARCH_HOST,
          apiKey: process.env.MEILISEARCH_API_KEY,
        },
        settings: {
          products: {
            indexSettings: {
              searchableAttributes: [
                "title", 
                "description",
                "variant_sku",
              ],
              displayedAttributes: [
                "id", 
                "title", 
                "description", 
                "thumbnail", 
                "handle",
                "variant_sku",
              ],
              sortableAttributes: [
                "created_at",
                "updated_at",
              ],
            },
            primaryKey: "id",
            transformer: (product) => ({
              id: product.id,
              title: product.title,
              description: product.description,
              thumbnail: product.thumbnail,
              handle: product.handle,
              created_at: product.created_at,
              updated_at: product.updated_at,
              variant_sku: product.variants.map((v) => v.sku),
            }),
          },
        },
      },
    },
    {
      resolve: `medusa-plugin-resend`,
      options: {
        api_key: process.env.RESEND_API_KEY,
        from: process.env.RESEND_FROM,
        // Optional: enable template sending
        // template_path: 'path/to/templates',
      },
    },
  ],
  modules: {
    [COMPANY_MODULE]: {
      resolve: "./modules/company",
    },
    [QUOTE_MODULE]: {
      resolve: "./modules/quote",
    },
    [APPROVAL_MODULE]: {
      resolve: "./modules/approval",
    },
    [Modules.CACHE]: {
      resolve: "@medusajs/medusa/cache-redis",
      options: {
        redisUrl: REDIS_URL,
      },
    },
    [Modules.EVENT_BUS]: {
      resolve: "@medusajs/event-bus-redis",
      options: {
        redisUrl: REDIS_URL,
      },
    },
    [Modules.WORKFLOW_ENGINE]: {
      resolve: "@medusajs/medusa/workflow-engine-inmemory",
    },
  },
});
