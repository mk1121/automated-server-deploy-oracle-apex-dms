#!/bin/bash
# 03_install_apex.sh
# Installs Oracle APEX.
set -e
# --- Configuration ---
source ./config.env || { echo "ERROR: config.env not found"; exit 1; }

# Adjust matches if needed
APEX_ZIP=$(find . -maxdepth 1 -name "apex*.zip" | head -n 1)
if [ -z "$APEX_ZIP" ]; then
    echo "ERROR: APEX zip file not found."
    echo "Please download APEX (e.g., apex_23.2.zip) and place it here."
    exit 1
fi
if [ ! -d "$ORACLE_HOME" ]; then
    echo "ERROR: ORACLE_HOME $ORACLE_HOME does not exist. Verify Oracle install."
    exit 1
fi
echo "Unzipping APEX to $ORACLE_HOME..."
# Usually unzipping 'apex_x.x.zip' acts into an 'apex' folder.
# We will unzip to /tmp/apex_extract and move it to ORACLE_HOME/apex or similar.
# Actually, standard practice: unzip in a directory, e.g., /home/oracle or /opt/oracle.
# Let's put it in /opt/oracle/apex
TARGET_DIR="$APEX_INSTALL_DIR"
unzip -q "$APEX_ZIP" -d "$TARGET_DIR"
chown -R oracle:oinstall "$TARGET_DIR/apex"
echo "Running APEX installation SQL scripts..."
echo "This may take a while."
cd "$TARGET_DIR/apex"
# We need to run sqlplus as sysdba.
# We'll use a HERE document to pipe commands to sqlplus.
# Ensure we switch to oracle user for this.
# CONNECT STRING: We must connect to the CDB root or PDB depending on where we want APEX.
# "install apex latest ... create container inside the db" => implies APEX in PDB.
# If connecting to PDB, we need the easy connect string: localhost:1521/ORCLPDB1
# But initial setup is usually done in CDB root for common user access, AND then linked in PDB.
# However, for a simple isolated setup, we can install directly in PDB if we want only PDB to have it.
# Standard 19c multitenant approach: Install in CDB root then sync to PDBs? No, APEX is local or common.
# Let's target the PDB directly as requested.
# NOTE: Listener must be running.
# Force start listener just in case config didn't
su - oracle -c "lsnrctl start || true"
# We use OS authentication (/ as sysdba) to avoid password issues.
# We connect to CDB then switch to PDB.
PDB_SERVICE="ORCLPDB1"
echo "Installing APEX into PDB: $PDB_SERVICE ..."
su - oracle -c "cd $TARGET_DIR/apex; sqlplus / as sysdba <<EOF
-- Stop on error
WHENEVER SQLERROR EXIT SQL.SQLCODE
-- Switch to PDB
ALTER SESSION SET CONTAINER = $PDB_SERVICE;
-- Install APEX
-- Arguments: tablespace_apex tablespace_files tablespace_temp images_prefix
@apexins.sql SYSAUX SYSAUX TEMP /i/
-- Change Admin Password (Optional automation, harder to do securely in script without args)
-- We will skip auto-password change and let user do it or print instructions.
-- Config REST
@apex_rest_config_core.sql /opt/oracle/apex/images
EXIT;
EOF"
echo "APEX Installation Complete."
echo "NOTE: You still need to:"
echo "1. Change the APEX Admin password by running '@apxchpwd.sql' in sqlplus as sysdba."
echo "2. Unlock the APEX_PUBLIC_USER account if needed."
echo "3. Configure a web server (ORDS) to serve APEX."

