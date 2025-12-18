#!/bin/bash
# 04_deploy_app.sh - Optimized for AlmaLinux/Oracle Linux
# Deploys Document Management System (React + Node + Oracle)

set -e

# Configuration
source ./config.env || { echo "ERROR: config.env not found"; exit 1; }

APP_REPO="https://github.com/mk1121/document-management-system"
APP_DIR="/var/www/dms"
# Map config to local vars
DB_USER="$APP_DB_USER"
DB_PASS="$APP_DB_PASS"
PDB_SERVICE="ORCLPDB1"
DOMAIN="localhost" # ???????? ????? ???? ?? ?????? ???

echo "--- Starting Application Deployment ---"

# 1. Node.js ??? Bun ?????????
echo "Installing Node.js 20..."
dnf module reset nodejs -y
dnf module enable nodejs:20 -y
dnf install -y nodejs

echo "Installing Bun..."
if ! command -v bun &> /dev/null; then
    curl -fsSL https://bun.sh/install | bash
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
else
    echo "Bun already installed."
fi

# 2. Nginx ??? ???????? ???? ?????????
echo "Installing Nginx and Git..."
dnf install -y epel-release
dnf install -y git nginx --disableexcludes=all

# 3. ????????? ?????
if [ -d "$APP_DIR" ]; then
    echo "Updating existing repository..."
    cd "$APP_DIR"
    git pull
else
    echo "Cloning repository..."
    mkdir -p /var/www
    git clone "$APP_REPO" "$APP_DIR"
fi

# 4. ??????? ????? ????? (Oracle)
echo "Setting up Database User..."
CMD="
export ORACLE_SID=ORCLCDB
sqlplus / as sysdba <<INNER_EOF
ALTER SESSION SET CONTAINER = $PDB_SERVICE;
WHENEVER SQLERROR CONTINUE;
CREATE USER $DB_USER IDENTIFIED BY \"$DB_PASS\";
GRANT CONNECT, RESOURCE, UNLIMITED TABLESPACE TO $DB_USER;
GRANT CREATE VIEW TO $DB_USER;
EXIT;
INNER_EOF
"
# oracle ????? ????? ??? ????, ?? ????? ????? ???? (??? ??????????)
su - oracle -c "$CMD" || echo "Oracle setup failed, skipping (Assuming DB is already set or remote)"

# 5. ????????? ?????
echo "Setting up Backend..."
cd "$APP_DIR/backend"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

bun install --frozen-lockfile

cat <<EOF > .env
PORT=3001
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASS
DB_CONNECT_STRING=//localhost:1521/$PDB_SERVICE
EOF

# Systemd Service for Backend
cat <<EOF > /etc/systemd/system/dms-backend.service
[Unit]
Description=DMS Backend
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR/backend
ExecStart=$(which node) server.js
Restart=on-failure
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable dms-backend --now || echo "Warning: Backend service failed to start"

# 6. ?????????? ????? (React/Vite)
echo "Building Frontend..."
cd "$APP_DIR"
bun install --frozen-lockfile

# Vite .env (API proxy ?? ???? /api ??????? ??? ?????)
echo "VITE_API_BASE_URL=/api" > .env

bun run build

# 7. Nginx ?????????? (??????)
echo "Configuring Nginx..."

# ?????? ????? ?????
rm -f /etc/nginx/conf.d/*.conf

# ???? nginx.conf ????? (?????? ??????? ???? ?????? ????)
cat <<EOF > /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
events { worker_connections 1024; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    include /etc/nginx/conf.d/*.conf;
}
EOF

# ????? ????? (Redirect Cycle ????? ???? try_files ? $uri/ /index.html ??????? ??? ?????)
cat <<EOF > /etc/nginx/conf.d/dms.conf
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name $DOMAIN;

    root $APP_DIR/dist;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html =404;
    }

    location /api/ {
        proxy_pass http://localhost:3001/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# 8. ??????? ??? SELinux ????? (AlmaLinux ?? ???? ?????? ????????????)
echo "Fixing Permissions and SELinux..."
chown -R nginx:nginx $APP_DIR
chmod -R 755 $APP_DIR
# /var/www ??????? ??????? ??????? ???
chmod 755 /var/www

if command -v getenforce &> /dev/null; then
    # ?????????? ???? ???????? ?????? ????? ???
    chcon -Rt httpd_sys_content_t $APP_DIR/dist
    # Nginx ?? ??????????? ???? ??????? ???? ?????? ?????
    setsebool -P httpd_can_network_connect 1
fi

# 9. ??????????? ??? ??????? ?????????
echo "Restarting Nginx..."
nginx -t
systemctl enable nginx --now
systemctl restart nginx

if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-port=3001/tcp
    firewall-cmd --reload || true
fi

echo "--- Deployment Complete! ---"
echo "URL: http://$DOMAIN"