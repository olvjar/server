#!/bin/bash

# ... existing logging setup code ...

# Function to prompt for input with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local response
    
    read -p "$prompt [$default]: " response
    echo "${response:-$default}"
}

# Function to prompt for password choice
prompt_for_password() {
    local choice
    local password
    
    while true; do
        echo "Choose password generation method:"
        echo "1) Generate random password using OpenSSL"
        echo "2) Enter custom password"
        read -p "Enter choice (1 or 2): " choice
        
        case $choice in
            1)
                password=$(openssl rand -base64 16)
                echo "Generated password: $password"
                break
                ;;
            2)
                read -s -p "Enter your custom password: " password
                echo
                read -s -p "Confirm your password: " password2
                echo
                if [ "$password" = "$password2" ]; then
                    break
                else
                    echo "Passwords don't match. Please try again."
                fi
                ;;
            *)
                echo "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
    echo "$password"
}

# Interactive prompts for variables
log "[!] Starting interactive configuration..."
DB_NAME="gitea"  # Fixed value
DB_USER=$(prompt_with_default "Enter database username" "gitea")
DB_PASS=$(prompt_for_password)
DOMAIN=$(prompt_with_default "Enter your domain name" "git.example.com")
SSL_CERT=$(prompt_with_default "Enter path to SSL certificate" "/etc/ssl/certs/your_cert.crt")
SSL_KEY=$(prompt_with_default "Enter path to SSL private key" "/etc/ssl/private/your_key.key")

# Display configuration summary
echo
log "[!] Configuration Summary:"
echo "Database Name: $DB_NAME"
echo "Database User: $DB_USER"
echo "Domain: $DOMAIN"
echo "SSL Certificate Path: $SSL_CERT"
echo "SSL Key Path: $SSL_KEY"
echo

# Confirm before proceeding
read -p "Do you want to proceed with this configuration? (y/N) " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    log "Configuration cancelled by user"
    exit 1
fi

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