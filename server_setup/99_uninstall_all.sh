#!/bin/bash
# 99_uninstall_all.sh
# COMPLETELY REMOVES Oracle 19c, APEX, ORDS, Nginx Configs, and the DMS App.
# USE WITH CAUTION.

echo "=========================================================="
echo "      WARNING: DESTRUCTIVE UNINSTALLATION SCRIPT"
echo "=========================================================="
echo "This script will PERMANENTLY REMOVE:"
echo " - Oracle Database 19c (and all data)"
echo " - Oracle APEX & ORDS"
echo " - The Custom Node.js Application (/var/www/dms)"
echo " - Nginx Configurations for the app"
echo " - Systemd services (dms-backend, nginx)"
echo ""
read -p "Type 'DELETE' to confirm you want to proceed: " CONFIRM

if [ "$CONFIRM" != "DELETE" ]; then
    echo "Confirmation failed. Aborting."
    exit 1
fi

echo "Starting cleanup..."

# 1. Stop and Disable Services
echo "--- Stopping Services ---"
systemctl disable --now dms-backend || echo "dms-backend service not found/active."
systemctl disable --now nginx || echo "nginx service not found/active."

# Force kill related processes in case systemd failed
echo "--- Killing Processes ---"
pkill -f "node server.js" || true
pkill -f "nginx" || true
pkill -f "ords" || true
pkill -f "java" || true # Warning: might kill other java apps if any

# 2. Remove Application
echo "--- Removing Application ---"
rm -rf /var/www/dms
echo "Removed /var/www/dms"

# 3. Remove Nginx Configs
echo "--- Cleaning Nginx Configs ---"
rm -f /etc/nginx/conf.d/dms.conf
rm -f /etc/nginx/conf.d/default.conf
# We can reinstall default nginx conf if desired, but leaving clean is okay
echo "Restoring default nginx.conf is left to the user if needed."

# 4. Uninstall Oracle 19c
echo "--- Uninstalling Oracle Database ---"
if rpm -q oracle-database-ee-19c; then
    dnf remove -y oracle-database-ee-19c
    echo "Oracle RPM removed."
else
    echo "Oracle RPM not found."
fi

# Clean up Oracle Directories
echo "--- cleaning Oracle Directories ---"
rm -rf /opt/oracle
rm -rf /etc/sysconfig/oracle*
rm -rf /etc/init.d/oracle*
rm -rf /etc/ords
rm -f /etc/yum.repos.d/oracle* # careful if they want to keep repo
# Keeping repo is usually fine.

# 5. Clean Environment Variables (from bashrc)
# We won't edit bashrc automatically to avoid messing up user custom configs, 
# but we can warn.
echo "NOTE: ~/.bashrc still contains ORACLE environment variables."
echo "You may want to edit it manually to remove lines ending in '# Oracle Env' or similar."

# 6. Remove Oracle Users (Optional - aggressive)
# echo "--- Removing Oracle User ---"
# userdel -r oracle || true
# groupdel oinstall || true
# groupdel dba || true

echo "=========================================================="
echo "Cleanup Complete."
echo "You can now run 'setup_all.sh' to perform a fresh install."
echo "=========================================================="
