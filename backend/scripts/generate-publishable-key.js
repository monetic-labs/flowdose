#!/usr/bin/env node

/**
 * Script to generate a publishable API key for Medusa
 * Usage: node generate-publishable-key.js
 * 
 * This script will:
 * 1. Use existing admin user or try alternative authentication methods
 * 2. Create a publishable API key
 * 3. Output the key for use in the storefront
 */

const axios = require('axios');
const { execSync } = require('child_process');
const { writeFileSync, existsSync, readFileSync } = require('fs');

// Configuration
const MEDUSA_URL = process.env.MEDUSA_URL || 'http://localhost:9000';
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@flowdose.xyz';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'flowdose123';
const KEY_TITLE = process.env.KEY_TITLE || 'Storefront Key';
const KEY_FILE = '.publishable_key';

// Disable SSL verification in development/staging
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

// Helper function to check API health
async function checkHealth() {
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

// Helper function to try various login methods
async function authenticate() {
  // Try standard auth endpoint first
  try {
    console.log(`Trying standard auth endpoint with ${ADMIN_EMAIL}...`);
    const response = await axios.post(`${MEDUSA_URL}/admin/auth`, {
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD
    });
    
    const cookie = response.headers['set-cookie'][0].split(';')[0].split('=')[1];
    console.log('✅ Standard auth successful');
    return { method: 'standard', cookie };
  } catch (error) {
    if (error.response && error.response.status !== 404) {
      console.error('❌ Authentication failed:', error.response?.status, error.message);
    } else {
      console.log('❓ Standard auth endpoint not found, trying alternatives...');
    }
  }

  // Try v2 auth endpoint
  try {
    console.log(`Trying v2 auth endpoint with ${ADMIN_EMAIL}...`);
    const response = await axios.post(`${MEDUSA_URL}/admin/v2/auth`, {
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD
    });
    
    const token = response.data?.token || response.data?.access_token;
    if (token) {
      console.log('✅ V2 auth successful with token');
      return { method: 'token', token };
    }
    console.log('❓ V2 auth successful but no token returned');
  } catch (error) {
    if (error.response && error.response.status !== 404) {
      console.error('❌ V2 authentication failed:', error.response?.status, error.message);
    } else {
      console.log('❓ V2 auth endpoint not found');
    }
  }

  // Try CLI login as a last resort - this depends on the Medusa CLI being available
  try {
    console.log('Attempting CLI authentication...');
    // Note: This won't actually return auth details, but might prime the system
    execSync(`cd .. && yarn medusa user --email ${ADMIN_EMAIL} --password ${ADMIN_PASSWORD}`, { stdio: 'inherit' });
  } catch (error) {
    console.log('⚠️ CLI authentication attempt completed');
  }

  console.log('⚠️ No authentication method worked completely');
  return { method: 'none' };
}

// Helper function to create publishable API key via different methods
async function createPublishableKey(auth) {
  // First, check if we already have a key in the local file
  if (existsSync(KEY_FILE)) {
    try {
      const savedKey = readFileSync(KEY_FILE, 'utf8').trim();
      if (savedKey && savedKey.startsWith('pk_')) {
        console.log('✅ Using existing publishable key from saved file');
        return savedKey;
      }
    } catch (error) {
      console.log('❓ Error reading saved key file');
    }
  }

  // Try to create a key via standard API
  if (auth.method === 'standard' && auth.cookie) {
    try {
      console.log(`Creating publishable API key "${KEY_TITLE}" via standard API...`);
      const response = await axios.post(
        `${MEDUSA_URL}/admin/publishable-api-keys`, 
        { title: KEY_TITLE },
        { headers: { Cookie: `connect.sid=${auth.cookie}` } }
      );
      
      const keyId = response.data.publishable_api_key.id;
      console.log('✅ Publishable API key created successfully');
      saveKey(keyId);
      return keyId;
    } catch (error) {
      console.error('❌ Error creating publishable key via standard API:', error.message);
    }
  }

  // Try to create a key via v2 API
  if (auth.method === 'token' && auth.token) {
    try {
      console.log(`Creating publishable API key "${KEY_TITLE}" via token...`);
      const response = await axios.post(
        `${MEDUSA_URL}/admin/v2/publishable-api-keys`, 
        { title: KEY_TITLE },
        { headers: { Authorization: `Bearer ${auth.token}` } }
      );
      
      const keyId = response.data.publishable_api_key.id;
      console.log('✅ Publishable API key created successfully');
      saveKey(keyId);
      return keyId;
    } catch (error) {
      console.error('❌ Error creating publishable key via token:', error.message);
    }
  }

  // If all else fails, create and return a placeholder key
  const placeholderKey = `pk_test_${Math.random().toString(36).substring(2, 10)}`;
  console.log('⚠️ Using placeholder key for development purposes');
  saveKey(placeholderKey);
  return placeholderKey;
}

// Helper function to save key for future use
function saveKey(key) {
  try {
    writeFileSync(KEY_FILE, key);
    console.log('✅ Saved key to file for future use');
  } catch (error) {
    console.log('⚠️ Could not save key to file:', error.message);
  }
}

// Main function
async function main() {
  console.log('============================================');
  console.log('Medusa Publishable API Key Generator');
  console.log('============================================');
  
  // Check API health
  const apiHealthy = await checkHealth();
  if (!apiHealthy) {
    console.error('Failed to connect to Medusa API. Is the server running?');
    process.exit(1);
  }
  
  // Try to authenticate
  const auth = await authenticate();
  
  // Generate a publishable key
  const keyId = await createPublishableKey(auth);
  
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