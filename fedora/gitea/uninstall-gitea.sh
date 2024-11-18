#!/bin/bash

# Script to uninstall Gitea from Fedora Server
# This script will remove Gitea and its configurations from the system.

LOG_FILE="/var/log/gitea_uninstall.log"
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
GITEA_USER="gitea"
GITEA_DIR="/var/lib/gitea"
GITEA_CONFIG="/etc/gitea"
GITEA_BINARY="/usr/local/bin/gitea"
GITEA_SERVICE="/etc/systemd/system/gitea.service"
NGINX_CONFIG="/etc/nginx/conf.d/gitea.conf"

# Stop and disable Gitea service
log "[!] Stopping and disabling Gitea service..."
systemctl stop gitea || log "Gitea service is not running."
systemctl disable gitea || log "Gitea service is not enabled."

# Remove Gitea binary
log "[!] Removing Gitea binary..."
rm -f "$GITEA_BINARY"

# Remove Gitea user and directories
log "[!] Removing Gitea user and directories..."
userdel -r "$GITEA_USER" || log "Gitea user does not exist."
rm -rf "$GITEA_DIR"
rm -rf "$GITEA_CONFIG"

# Remove systemd service file
log "[!] Removing Gitea systemd service file..."
rm -f "$GITEA_SERVICE"
systemctl daemon-reload

# Remove Nginx configuration
log "[!] Removing Nginx configuration for Gitea..."
rm -f "$NGINX_CONFIG"
nginx -t && systemctl reload nginx || log "Nginx configuration test failed."

log "[!] Gitea uninstallation completed!"