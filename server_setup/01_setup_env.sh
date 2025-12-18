#!/bin/bash
# 01_setup_env.sh
# Handles user creation, system prerequisites, and Node.js installation.

set -e

# ---# Configuration
source ./config.env || { echo "ERROR: config.env not found"; exit 1; }

# Map config variables to local usage for clarity if needed, or use directly
NEW_USER="$SYSTEM_USER"
NEW_USER_PASS="$SYSTEM_PASS"
NODE_MAJOR=20
ORACLE_DISTR="oracle-database-preinstall-19c"

echo "Starting System Setup..."

# 1. Create User
if id "$NEW_USER" &>/dev/null; then
    echo "User $NEW_USER already exists. Skipping creation."
else
    echo "Creating user $NEW_USER..."
    useradd -m -s /bin/bash "$NEW_USER"
    echo "$NEW_USER:$NEW_USER_PASS" | chpasswd
    usermod -aG wheel "$NEW_USER"
    echo "User $NEW_USER created and added to wheel group."
fi

# 2. System Update & Dependencies
echo "Updating system packages..."
dnf update -y

echo "Installing Oracle Preinstall RPM..."
# Standard dnf install fails on AlmaLinux 8 because the package is in OL8 repos.
# We install it directly from the Oracle Linux yum server.
PREINSTALL_RPM_URL="https://yum.oracle.com/repo/OracleLinux/OL8/appstream/x86_64/getPackage/oracle-database-preinstall-19c-1.0-1.el8.x86_64.rpm"

# Install using dnf to handle dependencies (it might prompt for GPG keys, -y handles it)
dnf install -y "$PREINSTALL_RPM_URL"


# 3. Node.js Installation
echo "Installing Node.js..."
# Check if node is already installed
if command -v node &> /dev/null; then
    echo "Node.js is already installed: $(node -v)"
else
    dnf module enable -y nodejs:18
    dnf install -y nodejs
    echo "Node.js $(node -v) installed."
fi

# 4. Firewall & SELinux
echo "Configuring Firewall..."
# Oracle Listener
firewall-cmd --permanent --add-port=1521/tcp
# APEX / ORDS (assuming 8080 default for standalone)
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload

echo "Configuring SELinux..."
if [ -f "/etc/selinux/config" ]; then
    sed -i 's/^SELINUX=.*/SELINUX=permissive/g' /etc/selinux/config
    setenforce 0 || true
else
    echo "SELinux config not found (common in containers). Skipping."
fi

echo "Environment Setup Complete."
echo "NEXT STEP: Run ./02_install_oracle.sh to install the Database."

