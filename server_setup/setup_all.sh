#!/bin/bash
# setup_all.sh
# Master script to execute setup stages.

set -e

# Permissions
chmod +x 01_setup_env.sh 02_install_oracle.sh 03_install_apex.sh 04_deploy_app.sh

echo "==========================================="
echo "  Oracle 19c + APEX + Node.js Setup Guide  "
echo "==========================================="
echo ""
echo "Step 1: Environment Setup"
./01_setup_env.sh
echo ""
echo "Step 2: Oracle 19c Installation"
./02_install_oracle.sh
echo ""
echo "Step 3: APEX Installation"
./03_install_apex.sh
echo ""
echo "Step 4: Application Deployment"
./04_deploy_app.sh
echo ""
echo "Step 5: ORDS Installation"
./05_install_ords.sh
echo ""

echo "==========================================="
echo "  All automated stages complete!"
echo "==========================================="
