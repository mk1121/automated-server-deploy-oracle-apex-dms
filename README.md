# Automated Server Deployment for DMS & Oracle APEX

This repository contains a suite of automation scripts designed to deploy a full-stack environment on **AlmaLinux 8**.

## Architecture Overview

The scripts provision a single-server environment with the following components:

*   **Database**: Oracle Database 19c Enterprise Edition (CDB + PDB `ORCLPDB1`).
*   **Application Platform**: Oracle APEX 23.2 (installed in PDB).
*   **Web Server (Middle Tier)**:
    *   **Nginx**: Reverse proxy serving the frontend on Port 80.
    *   **ORDS (Oracle REST Data Services)**: Java-based listener for APEX (Standalone Mode).
*   **Application**:
    *   **Backend**: Node.js (v20) Express API connecting to Oracle via `node-oracledb`.
    *   **Frontend**: React (Vite) Single Page Application served statically by Nginx.

---

## 1. Prerequisites

Before running the scripts, you must ensure:

1.  **OS**: AlmaLinux 8 (Clean Install recommended).
2.  **Root Access**: Scripts must be run as `root` (or with `sudo`).
3.  **Oracle Binaries**: You must manually download the following proprietary files and place them in this directory (`server_setup/`):
    *   `oracle-database-ee-19c-1.0-1.x86_64.rpm` (Linux x86-64 RPM)
    *   `apex_23.2.zip` (Oracle APEX)
    *   `ords-*.zip` or `ords-*.rpm` (Oracle REST Data Services)

---

## 2. Global Configuration

**ALL Configuration** is now centralized in `config.env`.
Edit this file **BEFORE** running any scripts to change passwords, ports, or users.

| Variable | Default | Description |
| :--- | :--- | :--- |
| `DB_SYS_PASSWORD` | `OrclAdmin123!` | Master Password for SYS, SYSTEM, etc. |
| `APP_PORT` | `3001` | Backend Node.js Port |
| `DOMAIN` | `localhost` | Server Domain / IP |
| `APP_DB_USER` | `DOCUSER` | App DB User |
| `APP_DB_PASS` | `DocUser123!` | App DB Password |

---

## 3. Installation Guide

### Step 1: Upload Files
Transfer this `server_setup` folder to your server:
```bash
scp -r server_setup root@<your-server-ip>:/root/
```

### Step 2: Run Automation
SSH into the server and execute the master script:
```bash
cd /root/server_setup
chmod +x setup_all.sh
./setup_all.sh
```

This will run the following sequence:
1.  **`01_setup_env.sh`**: System prep, firewall, users, Node.js 20.
2.  **`02_install_oracle.sh`**: Oracle 19c installation & configuration.
3.  **`03_install_apex.sh`**: APEX installation into `ORCLPDB1`.
4.  **`04_deploy_app.sh`**: DMS App deployment (Nginx, Git, Node.js, Systemd).
5.  **`05_install_ords.sh`**: Java & ORDS installation (creates helper script).

### Step 3: Finalize ORDS
Due to security sensitivity, the final ORDS password configuration is separated.
After `setup_all.sh` completes, run:
```bash
./finish_ords_setup.sh
```
This script handles:
*   Resetting `SYS` passwords in the CDB scope.
*   Unlocking `APEX_PUBLIC_USER`.
*   Configuring ORDS with the correct static file paths.

---

## 4. Post-Install Verification

1.  **Application Access**:
    *   Open `http://<your-server-ip>/` in a browser.
    *   You should see the React Login screen.

2.  **Backend Status**:
    *   Check service: `systemctl status dms-backend`
    *   Test API: `curl http://localhost:3001/api/health` (if endpoint exists).

3.  **APEX Access**:
    *   If configured, APEX is served through ORDS.
    *   Default internal url (if running): `http://localhost:8080/ords`

---

## 5. Troubleshooting Common Issues

### "Welcome to Nginx" Page Persists
*   **Cause**: Default Nginx config (`default.conf`) conflicting with app config.
*   **Fix**: The scripts now auto-remove this file. Run: `rm /etc/nginx/conf.d/default.conf && systemctl reload nginx`.

### Application Unreachable (Connection Refused)
*   **Cause**: Firewall blocking ports.
*   **Fix**: Ensure ports are open:
    ```bash
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-port=3001/tcp
    firewall-cmd --reload
    ```

### ORDS: "ORA-01017: invalid username/password"
*   **Cause**: `SYS` password mismatch or scope issue (CDB vs PDB).
*   **Fix**: Reset password in CDB Root:
    ```sql
    sqlplus / as sysdba
    ALTER USER SYS IDENTIFIED BY "OrclAdmin123!" CONTAINER=ALL;
    ```

### ORDS: "ORA-28000: The account is locked"
*   **Cause**: `APEX_PUBLIC_USER` is locked by default 19c security.
*   **Fix**: Unlock in PDB:
    ```sql
    ALTER SESSION SET CONTAINER = ORCLPDB1;
    ALTER USER APEX_PUBLIC_USER ACCOUNT UNLOCK;
    ```

### APEX Images Not Loading (404/Missing)
*   **Cause**: ORDS doesn't know where static files are, or permissions are wrong.
*   **Fix**:
    1.  Set config: `ords config set standalone.static.path /opt/oracle/apex/images`
    2.  Fix permissions: `chmod -R 755 /opt/oracle/apex/images`

---

## 6. Uninstallation / Cleanup

**WARNING: DATA LOSS**. To completely remove everything and reset the environment:
```bash
chmod +x 99_uninstall_all.sh
sudo ./99_uninstall_all.sh
```
This removes Oracle, APEX, ORDS, Nginx configs, and the application.
