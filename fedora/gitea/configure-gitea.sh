#!/bin/bash

# Script to configure MariaDB and Nginx for Gitea with SSL support for custom domain
# This script assumes Gitea has been installed using the first script.

LOG_FILE="/var/log/gitea_configure.log"
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1  # Redirect output to both console and log file

# Function to log messages with timestamp
log() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message"
}

# Exit immediately if a command exits with a non-zero status
set -e

# Ensure the script is being run as root
if [ "$(whoami)" != "root" ]; then
    log "This script needs to be run as root or with sudo."
    log "sudo $0 $*"
    exit 1
fi

# Variables
DB_NAME="gitea"
DB_USER="gitea"
DB_PASS=$(openssl rand -base64 16) # or "your_secure_password" // Change this to a secure password
DOMAIN="git.olvjar.com"
SSL_CERT="/etc/ssl/certs/your_cert.crt"  # Path to your SSL certificate
SSL_KEY="/etc/ssl/private/your_key.key"   # Path to your SSL key

install_missing() {
    local package="$1"
    if ! dnf -q list installed "$package" &>/dev/null; then
        log "Installing $package..."
        if dnf install -y "$package"; then
            log "$package installed successfully."
        else
            log "Failed to install $package. Exiting."
            exit 1
        fi
    else
        log "$package is already installed."
    fi
}

# Install MariaDB and Nginx if not already installed
log "[!] Checking and installing dependencies..."
dependencies=("mariadb-server" "nginx")
for package in "${dependencies[@]}"; do
    install_missing "$package"
done

# Start and enable MariaDB and Nginx services
log "[!] Starting services..."
systemctl start mariadb
systemctl enable mariadb
systemctl start nginx
systemctl enable nginx

# Configure MariaDB for Gitea
log "[!] Configuring MariaDB for Gitea..."
mysql -u root -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

log "[!] MariaDB configured for Gitea."

# Configure Nginx for Gitea with SSL support
log "[!] Configuring Nginx for Gitea..."
cat <<EOF >/etc/nginx/conf.d/gitea.conf
server {
    listen 80;
    server_name $DOMAIN;

    # Redirect HTTP to HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate ${SSL_CERT};
    ssl_certificate_key ${SSL_KEY};

    location / {
        client_max_body_size 512M;
        proxy_pass http://localhost:3000;  # Gitea runs on port 3000 by default
        proxy_set_header Connection $http_connection;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 90;
    }
}
EOF

# Test Nginx configuration and reload it
nginx -t
systemctl reload nginx

log "[!] Nginx configured and reloaded with SSL for $DOMAIN."

# Update Gitea configuration file
log "[!] Updating Gitea configuration..."
cat <<EOF >/etc/gitea/app.ini
[database]
DB_TYPE = mysql
HOST = localhost:3306
NAME = $DB_NAME
USER = $DB_USER
PASSWD = $DB_PASS
SSL_MODE = disable

[server]
DOMAIN = $DOMAIN
HTTP_PORT = 3000
ROOT_URL = https://$DOMAIN/
DISABLE_SSH = false
EOF

# Restart Gitea service to apply changes
systemctl restart gitea

log "[!] Gitea, MariaDB, and Nginx configuration complete! Gitea should now be accessible at https://$DOMAIN"