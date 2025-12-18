#!/bin/bash
# 05_install_ords.sh
# Installs and configures Oracle REST Data Services (ORDS).

set -e

# Configuration
source ./config.env || { echo "ERROR: config.env not found"; exit 1; }

# Local mappings (if names differ slightly or for clarity)
ORDS_CONF_DIR="$ORDS_CONFIG_DIR"
JAVA_VER="java-17-openjdk"
DB_HOST="localhost"
DB_PORT="1521"
DB_SERVICE="$PDB_SERVICE"
# ORDS_PORT defined in config.env

echo "Installing Java 17..."
dnf install -y $JAVA_VER

# Find Installer
# RPM is preferred for easier system integration
ORDS_RPM=$(find . -maxdepth 1 -name "ords*.rpm" | head -n 1)

if [ -n "$ORDS_RPM" ]; then
    echo "Found ORDS RPM: $ORDS_RPM"
    dnf localinstall -y "$ORDS_RPM"
    # ORDS RPM usually puts executable using 'ords' wrapper
else
    # Try Zip
    ORDS_ZIP=$(find . -maxdepth 1 -name "ords*.zip" | head -n 1)
    if [ -n "$ORDS_ZIP" ]; then
        echo "Found ORDS Zip: $ORDS_ZIP"
        mkdir -p "$ORDS_HOME"
        unzip -q "$ORDS_ZIP" -d "$ORDS_HOME"
        echo "ORDS unzipped to $ORDS_HOME"
        # Create executable symlink for convenience logic if needed, but modern ORDS has bin/ords
        export PATH=$ORDS_HOME/bin:$PATH
    else
        echo "ERROR: Please provide ords-*.rpm or ords-*.zip"
        exit 1
    fi
fi

echo "Configuring ORDS..."

# Interactive installation is complex to script. 
# We use 'ords install' with command line options if possible, or response file.
# Modern ORDS (22+) uses 'ords install --interactive' mostly.
# We will assume a basic standalone setup.

# Ensure simple-install (interactive prompt bypass)
# Note: ORDS automation is tricky without a response file or expect.
# We will create a configuration response if supported or warn user.

echo "WARNING: ORDS fully automated configuration requires known passwords and shell interactivity."
echo "Running basic standalone configuration..."

# Trying to use command line args for non-interactive (works in newer ORDS)
# ords --config /etc/ords/config install --admin-user SYS --db-hostname localhost --db-port 1521 --db-servicename ORCLPDB1 --feature-db-api true --feature-rest-enabled-sql true --feature-sdw true --gateway-mode proxied --gateway-user APEX_PUBLIC_USER --password-stdin

# Since we don't have passwords in variables reliably without passing them around,
# we will setup the folders and instruct the user to run the final config command.
# Or we try to run it if we trust the password 'OrclAdmin123!'.

# Resolve ORDS Bin Location
ORDS_BIN=""
if [ -f "/bin/ords" ]; then
    ORDS_BIN="/bin/ords"
elif [ -f "/usr/bin/ords" ]; then
    ORDS_BIN="/usr/bin/ords"
elif [ -f "$ORDS_HOME/bin/ords" ]; then
    ORDS_BIN="$ORDS_HOME/bin/ords"
fi

if [ -n "$ORDS_BIN" ]; then
    # Create configuration directory
    mkdir -p $ORDS_CONF_DIR
    
    echo "Using ORDS binary at: $ORDS_BIN"
    
    # Fix APEX Images Permissions (Ensure readable by all)
    if [ -d "/opt/oracle/apex/images" ]; then
        echo "Fixing permissions on APEX images..."
        chmod -R 755 /opt/oracle/apex/images
    fi
    
    echo "Please run the following command manually to finalize ORDS (due to password sensitivity):"

    echo "$ORDS_BIN --config $ORDS_CONF_DIR install \\"
    echo "     --admin-user SYS \\"
    echo "     --db-hostname $DB_HOST \\"
    echo "     --db-port $DB_PORT \\"
    echo "     --db-servicename $DB_SERVICE \\"
    echo "     --feature-db-api true \\"
    echo "     --feature-rest-enabled-sql true \\"
    echo "     --feature-sdw true \\"
    echo "     --gateway-mode proxied \\"
    echo "     --gateway-user APEX_PUBLIC_USER \\"
    echo "     --proxy-user \\"
    echo "     --password-stdin <<EOF"
    echo "OrclAdmin123!"
    echo "OrclAdmin123!"
    echo "EOF"
    
    # We create a helper script for them
    cat <<EOF > finish_ords_setup.sh
#!/bin/bash
echo "Ensuring DB Credentials are correct..."
# Force reset SYS password in CDB (Common User) to match what we pass to ORDS
# This propagates to PDBs
su - oracle -c "sqlplus / as sysdba <<SQL_EOF
ALTER USER SYS IDENTIFIED BY \"OrclAdmin123!\" CONTAINER=ALL;
ALTER SESSION SET CONTAINER = $DB_SERVICE;
ALTER USER APEX_PUBLIC_USER ACCOUNT UNLOCK;
ALTER USER APEX_PUBLIC_USER IDENTIFIED BY \"OrclAdmin123!\";
EXIT;
SQL_EOF"



echo "Configuring ORDS..."
# Configure Static Resources Path (Standalone Mode)
# This maps the default context path (usually /i) to the directory
$ORDS_BIN --config $ORDS_CONF_DIR config set standalone.static.path /opt/oracle/apex/images
$ORDS_BIN --config $ORDS_CONF_DIR config set standalone.static.context.path /i

$ORDS_BIN --config $ORDS_CONF_DIR install \\
     --admin-user SYS \\
     --db-hostname $DB_HOST \\
     --db-port $DB_PORT \\
     --db-servicename $DB_SERVICE \\
     --feature-db-api true \\
     --feature-rest-enabled-sql true \\
     --feature-sdw true \\
     --gateway-mode proxied \\
     --gateway-user APEX_PUBLIC_USER \\
     --password-stdin <<INNEREOF
OrclAdmin123!
OrclAdmin123!
INNEREOF


EOF


    chmod +x finish_ords_setup.sh
    echo "Created 'finish_ords_setup.sh'. Run it to complete ORDS setup."
    
else
    echo "ORDS executable not found. Installation might have failed."
    exit 1
fi

