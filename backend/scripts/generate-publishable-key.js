#!/usr/bin/env node

/**
 * Script to generate a publishable API key for Medusa
 * Usage: node generate-publishable-key.js
 * 
 * This script will:
 * 1. Use existing admin user or tell you to create one with the CLI
 * 2. Login to the Medusa admin API
 * 3. Create a publishable API key
 * 4. Output the key for use in the storefront
 */

const axios = require('axios');
const { execSync } = require('child_process');

// Configuration
const MEDUSA_URL = process.env.MEDUSA_URL || 'http://localhost:9000';
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@flowdose.xyz';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'flowdose123';
const KEY_TITLE = process.env.KEY_TITLE || 'Storefront Key';

// Disable SSL verification in development/staging
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

// Helper function to check if user exists via login
async function checkUserExists() {
  try {
    console.log(`Checking if admin user exists (${ADMIN_EMAIL})...`);
    const response = await axios.post(`${MEDUSA_URL}/admin/auth`, {
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD
    });
    console.log('✅ Admin user exists and credentials are valid');
    return response.headers['set-cookie'][0].split(';')[0].split('=')[1];
  } catch (error) {
    if (error.response && error.response.status === 401) {
      console.log('❌ Admin user exists but credentials are invalid');
      return null;
    } else if (error.response && error.response.status === 404) {
      console.log('❓ Admin auth endpoint not found - trying alternative approach');
      return null;
    } else {
      console.log('❌ Admin user likely does not exist');
      return null;
    }
  }
}

// Helper function to create admin user with CLI
function createUserWithCLI() {
  try {
    console.log(`Creating admin user with CLI (${ADMIN_EMAIL})...`);
    execSync(`yarn medusa user -e ${ADMIN_EMAIL} -p ${ADMIN_PASSWORD}`, { stdio: 'inherit' });
    console.log('✅ Admin user created successfully with CLI');
    return true;
  } catch (error) {
    console.error('❌ Error creating admin user with CLI');
    console.error('Please create a user manually with: yarn medusa user -e admin@example.com -p secure-password');
    return false;
  }
}

// Helper function to login to admin API
async function loginAdmin() {
  try {
    console.log(`Logging in as ${ADMIN_EMAIL}...`);
    const response = await axios.post(`${MEDUSA_URL}/admin/auth`, {
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD
    });
    
    // Extract cookie from response
    const cookie = response.headers['set-cookie'][0].split(';')[0].split('=')[1];
    console.log('✅ Login successful');
    return cookie;
  } catch (error) {
    console.error('❌ Login error:', error.message);
    
    if (error.response && error.response.status === 404) {
      console.log('❗ The admin auth endpoint was not found. This might be due to:');
      console.log('   - Using a different version of Medusa than expected');
      console.log('   - Custom authentication system');
      console.log('   - Admin API not enabled');
    }
    
    return null;
  }
}

// Helper function to check API structure
async function checkApiStructure() {
  try {
    console.log('Checking API structure...');
    const response = await axios.get(`${MEDUSA_URL}/health`);
    console.log('✅ API is healthy');
    return true;
  } catch (error) {
    console.error('❌ API health check failed:', error.message);
    return false;
  }
}

// Helper function to create publishable API key
async function createPublishableKey(cookie) {
  try {
    console.log(`Creating publishable API key "${KEY_TITLE}"...`);
    const response = await axios.post(
      `${MEDUSA_URL}/admin/publishable-api-keys`, 
      { title: KEY_TITLE },
      { headers: { Cookie: 'connect.sid=' + cookie } }
    );
    
    const keyId = response.data.publishable_api_key.id;
    console.log('✅ Publishable API key created successfully');
    return keyId;
  } catch (error) {
    if (error.response && error.response.status === 404) {
      console.error('❌ Publishable API key endpoint not found');
      console.log('  This could be due to using a different version of Medusa');
      
      // Suggest a placeholder key for development
      const placeholderKey = 'pk_test_' + Math.random().toString(36).substring(2, 15);
      console.log('  For development purposes, you can use this placeholder key:');
      console.log(`  ${placeholderKey}`);
      return placeholderKey;
    } else {
      console.error('❌ Error creating publishable key:', error.message);
      return null;
    }
  }
}

// Main function
async function main() {
  console.log('============================================');
  console.log('Medusa Publishable API Key Generator');
  console.log('============================================');
  
  // Check API structure
  const apiHealthy = await checkApiStructure();
  if (!apiHealthy) {
    console.error('Failed to connect to Medusa API. Is the server running?');
    process.exit(1);
  }
  
  // Check if user exists or create with CLI
  let cookie = await checkUserExists();
  if (!cookie) {
    const userCreated = createUserWithCLI();
    if (userCreated) {
      // Try login again after creating user
      cookie = await loginAdmin();
    }
  }
  
  if (!cookie) {
    console.error('Failed to authenticate. Please verify your Medusa setup and credentials.');
    console.log('For development, you can use a placeholder key:');
    const devKey = 'pk_test_' + Math.random().toString(36).substring(2, 15);
    console.log(`NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=${devKey}`);
    process.exit(1);
  }
  
  // Create publishable key
  const keyId = await createPublishableKey(cookie);
  if (!keyId) {
    console.error('Failed to create publishable key.');
    process.exit(1);
  }
  
  console.log('============================================');
  console.log('📝 Add the following to your .env file:');
  console.log(`NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=${keyId}`);
  console.log('============================================');
}

// Run the script
main().catch(error => {
  console.error('Unhandled error:', error);
  process.exit(1);
}); 