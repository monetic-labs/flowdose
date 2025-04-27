# Troubleshooting Admin Login Failures (401/404 Not Found)

## Problem Description

Attempts to log in to the Medusa Admin UI (`https://admin-staging.flowdose.xyz`) using the credentials specified in the environment variables (`admin@flowdose.xyz` / `flowdose`) failed.

- The UI showed a "Not Found" error.
- Browser developer tools showed a `POST` request to an auth endpoint (initially observed as `/auth/user/emailpass`, though the standard admin endpoint is `/admin/auth`) returning a `404 (Not Found)` status code.

## Investigation Steps & Findings

1.  **Database Check (Initial):**
    *   Connected to the PostgreSQL database (`postgres-flowdose-staging-0423`) via SSH to the backend server (`144.126.221.222`) using `psql`.
    *   Queried the `user`, `auth_identity`, and `provider_identity` tables for `admin@flowdose.xyz`.
    *   **Finding:** No records found for `admin@flowdose.xyz`.
    *   **Finding:** An incorrect user `admin@flowdose.com` existed in the `user` table but lacked corresponding `auth_identity` and `provider_identity` records.

2.  **Database Cleanup:**
    *   Deleted the incorrect `admin@flowdose.com` user record using `DELETE FROM "user" WHERE email = 'admin@flowdose.com';`.

3.  **Seeding Analysis:**
    *   Reviewed the `backend/src/scripts/seed.ts` script.
    *   **Finding:** The script populates products, regions, etc., but does *not* create the initial admin user. This confirmed user creation must happen manually (via CLI or initial Admin UI setup).

4.  **Manual User Creation Attempt:**
    *   Attempted to create the user via SSH using `medusa user -e admin@flowdose.xyz -p flowdose`.
    *   **Finding:** Command failed with `Error: Cannot find module 'ts-node'`.
    *   Verified `ts-node` existed locally in `/root/app/backend/node_modules/.bin/` using `ls`. The issue was likely the server's `PATH` not including the local bin directory.
    *   Successfully created the user via SSH using `npx medusa user -e admin@flowdose.xyz -p flowdose`. `npx` correctly located the local `ts-node`.

5.  **Post-Creation Login Failure:**
    *   Login still failed with the same `404 (Not Found)` error.

6.  **Database Check (Post-Creation):**
    *   Re-queried the database tables for `admin@flowdose.xyz`.
    *   **Finding:** All records (`user`, `auth_identity`, `provider_identity`) were now present and correctly linked, including the password hash.

7.  **Server Log Analysis:**
    *   Checked the `medusa-server` logs using `pm2 logs medusa-server`.
    *   **Finding:** Multiple errors `Error: listen EADDRINUSE: address already in use :::9000` indicated a port conflict.

8.  **Port Conflict Investigation:**
    *   Used `lsof -i :9000` via SSH to identify the process listening on port 9000. Found PID `159962` (a `node` process).
    *   Used `pm2 list` via SSH to list running processes managed by PM2. Found `medusa-server` (PID `161656`) and `medusa-worker` (PID `159845`).
    *   **Finding:** The process holding port 9000 (PID `159962`) was *not* managed by PM2, indicating a rogue/leftover process.

## Root Cause

A rogue `node` process (PID `159962`) was occupying port 9000 on the server. This prevented the `medusa-server` process, managed by PM2, from starting correctly and binding to the port. As a result, the Medusa backend API was unavailable or unstable, causing the 404 errors when the admin frontend tried to authenticate.

## Resolution

1.  Terminated the rogue process via SSH: `kill 159962`
2.  Restarted the legitimate server process via SSH: `pm2 restart medusa-server`

## Outcome

After terminating the conflicting process and restarting the server, the Medusa backend started successfully, bound to port 9000, and admin login became functional. 