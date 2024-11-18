#!/bin/bash

# Script to install Gitea on Fedora Server
# This script will install and configure Gitea on Fedora, ensuring all dependencies are installed and setup correctly.

LOG_FILE="/var/log/gitea_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1  # Redirect output to both console and log file

# Function to log messages with timestamp
log() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message"
}

# Function to wait for user input (used for manual intervention)
wait_input() {
    read -p "[*] Press Enter to continue..."
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
GITEA_USER="gitea"
GITEA_DIR="/var/lib/gitea"
GITEA_CONFIG="/etc/gitea"
GITEA_BINARY="/usr/local/bin/gitea"

# Function to install missing dependencies
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

# Main Installation Process
log "[!] Starting Gitea installation..."

# Update system and install dependencies
log "[!] Updating system..."
dnf update -y

log "[!] Checking and installing dependencies..."
dependencies=("git" "wget" "curl" "tar" "openssl")
for package in "${dependencies[@]}"; do
    install_missing "$package"
done

# Create Gitea user
log "[!] Creating Gitea user..."
if id "$GITEA_USER" &>/dev/null; then
    log "Gitea user already exists."
else
    useradd --system --shell /bin/bash --user-group --home-dir /home/gitea "$GITEA_USER"
    log "Gitea user created."
fi

# Set up Gitea directories and permissions
log "[!] Setting up user directories..."
mkdir -p "$GITEA_DIR"/{custom,data,log} "$GITEA_CONFIG"
chown -R "$GITEA_USER:$GITEA_USER" "$GITEA_DIR"
chown -R root:"$GITEA_USER" "$GITEA_CONFIG"
chmod -R 750 "$GITEA_DIR"
chmod -R 770 "$GITEA_CONFIG"

# Download and install Gitea
log "[!] Downloading Gitea..."
LATEST_VERSION=$(curl -s https://dl.gitea.io/gitea/ | grep -oP 'href="/gitea/\K\d+\.\d+\.\d+' | sort -V | tail -n 1)
wget -O /usr/local/bin/gitea "https://dl.gitea.io/gitea/${LATEST_VERSION}/gitea-${LATEST_VERSION}-linux-arm64"
chmod +x /usr/local/bin/gitea

# Create systemd service file for Gitea
log "[!] Setting up Gitea service..."
cat <<EOF >/etc/systemd/system/gitea.service
[Unit]
Description=Gitea (Git with a cup of tea)
After=network.target

[Service]
Type=simple
User=$GITEA_USER
Group=$GITEA_USER
WorkingDirectory=$GITEA_DIR
ExecStart=$GITEA_BINARY web -c $GITEA_CONFIG/app.ini
Restart=always
Environment=USER=$GITEA_USER HOME=/home/gitea GITEA_WORK_DIR=$GITEA_DIR
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start Gitea
systemctl daemon-reload
systemctl enable --now gitea
systemctl start gitea

log "[!] Gitea installation completed! Proceed with database and Nginx configuration."