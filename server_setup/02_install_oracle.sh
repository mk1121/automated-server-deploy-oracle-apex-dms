#!/bin/bash
# 02_install_oracle.sh
# Installs Oracle 19c from local RPM and configures the DB.

source ./config.env || { echo "ERROR: config.env not found"; exit 1; }

set -e

RPM_FILE=$(find . -maxdepth 1 -name "oracle-database-19c-*.rpm" | head -n 1)

if [ -z "$RPM_FILE" ]; then
    echo "ERROR: Oracle 19c RPM not found in current directory."
    echo "Please download 'oracle-database-19c-1.0-1.x86_64.rpm' (or similar) and place it here."
    exit 1
fi

echo "Found Oracle RPM: $RPM_FILE"
echo "Installing Oracle 19c..."

# Fix for Docker environments: explicit flag to bypass some limit checks in preinstall
export ORACLE_DOCKER_INSTALL=true

# Explicitly set the password variable expected by the Oracle Config script
export ORACLE_PASSWORD="$DB_SYS_PASSWORD"

dnf localinstall -y "$RPM_FILE"


echo "Configuring Oracle Database (Creating sample DB)..."
# Set PDB configurations
CONF_FILE="/etc/sysconfig/oracle-database-19c.conf"
if [ -f "$CONF_FILE" ]; then
    echo "Updating $CONF_FILE for PDB creation..."
    # Ensure a PDB is created. Default is often ORCLPDB1 but let's be explicit.
    sed -i 's/^#ORACLE_PDB=.*/ORACLE_PDB=ORCLPDB1/g' "$CONF_FILE"
    sed -i 's/^ORACLE_PDB=.*/ORACLE_PDB=ORCLPDB1/g' "$CONF_FILE"
    # Ensure CDB use
    sed -i 's/^#ORACLE_SID=.*/ORACLE_SID=ORCLCDB/g' "$CONF_FILE"
    sed -i 's/^ORACLE_SID=.*/ORACLE_SID=ORCLCDB/g' "$CONF_FILE"
    # Set Password (matches the one in 01_setup_env.sh and expectation)
    # Using OrclAdmin123!
    sed -i 's/^#ORACLE_PASSWORD=.*/ORACLE_PASSWORD=OrclAdmin123!/g' "$CONF_FILE"
fi

# This runs the default configuration script provided by the RPM

# This runs the default configuration script provided by the RPM
# We search for it because the name might vary.
# Debug parsing issue:
echo "Listing /etc/init.d/ contents:"
ls -l /etc/init.d/

# Use simple bash glob expansion to find the file
# We prioritize 'oracledb' prefixed scripts (new naming) or 'oracle-database' (old naming)
# AND we must exclude 'preinstall' scripts.
MATCHES=( /etc/init.d/oracledb*19c /etc/init.d/oracle-database*19c )

INIT_SCRIPT=""
for candidate in "${MATCHES[@]}"; do
    if [[ -f "$candidate" && "$candidate" != *"preinstall"* ]]; then
        INIT_SCRIPT="$candidate"
        break
    fi
done

if [ -z "$INIT_SCRIPT" ]; then
    echo "ERROR: Could not find Oracle configuration script (ignoring preinstall scripts)."
    echo "Available candidates were: ${MATCHES[*]}"
    exit 1
fi

echo "Running configuration script: $INIT_SCRIPT"
"$INIT_SCRIPT" configure





echo "Oracle 19c Installation & Configuration Complete."

# Auto-configure environment variables for root and oracle users
echo "Setting up environment variables..."
cat <<EOF > /etc/profile.d/oracle-env.sh
export ORACLE_HOME=/opt/oracle/product/19c/dbhome_1
export ORACLE_SID=${ORACLE_SID:-ORCLCDB}
export PATH=\$ORACLE_HOME/bin:\$PATH
EOF

# Update current shell for immediate usage if sourced, though usually applies to new shells
source /etc/profile.d/oracle-env.sh

echo "Environment variables set in /etc/profile.d/oracle-env.sh."
echo "You may need to log out and log back in, or run 'source /etc/profile.d/oracle-env.sh' to use 'sqlplus' in this session."







