#!/bin/bash

# logging
LOG_FILE="/var/log/gitea_install.log"
exec > >(tee -a "$LOGFILE") 2>&1. # redirect output to both console and log file

# function to log messages
log() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message"
}

# function to wait for user input
wait_input() {
    read -p "[*] Press Enter to continue..."
}

# exit immediately if a command exits with a non-zero status
set -e

# check current user permissions
if [ "$(whoami)" != "root" ]; then
    log "This script needs to be run as root or with sudo."
    log "sudo $0 $*"
    exit 1
fi

# Function to check and install a package
install_package() {
    local pkg=$1
    if ! dnf -q list installed "$pkg" &>/dev/null; then
        log "Installing $pkg..."
        if dnf install -y "$pkg"; then
            log "$pkg installed successfully."
        else
            log "Failed to install $pkg. Exiting."
            exit 1
        fi
    else
        log "$pkg is already installed."
    fi
}

# Define packages
packages=(
    "neovim" "git" "fish" "tmux" "net-tools" "bat"
    "nginx" "httpd" "php" "mariadb-server"
)

# Define services to enable/start
services=(
    "httpd" "mariadb" "nginx"
)

# Define firewall services
firewall_services=(
    "ssh" "http" "https" "mysql" "cockpit"
)

# Update system
log "[!] Updating system..."
dnf update -y
wait_input

# Install packages
log "[!] Installing packages..."
for pkg in "${packages[@]}"; do
    install_package "$pkg"
done
wait_input

# Check and install firewalld if not installed
if ! dnf -q list installed firewalld &>/dev/null; then
    log "Installing firewalld..."
    dnf install -y firewalld
    log "firewalld installed successfully."
else
    log "firewalld is already installed."
fi
wait_input

# Enable and start necessary services
log "[!] Enabling and starting services..."
for service in "${services[@]}"; do
    systemctl enable "$service"
    systemctl start "$service"
done
systemctl enable --now firewalld
wait_input

# Allow necessary services through the firewall
log "[!] Allowing necessary services through the firewall..."
for fw_service in "${firewall_services[@]}"; do
    firewall-cmd --permanent --add-service="$fw_service"
done
firewall-cmd --reload
wait_input

# Set Fish as the default shell
log "[!] Setting Fish as the default shell for the user..."
if command -v fish &>/dev/null; then
    chsh -s "$(command -v fish)"
    if [[ $? -eq 0 ]]; then
        log "Fish has been set as the default shell."
    else
        log "Failed to set Fish as the default shell. You may need to log out and log back in."
    fi
else
    log "Fish is not installed. Cannot set as default shell."
fi
wait_input

# Cleanup unused packages
log "[!] Cleaning up unused packages..."
dnf autoremove -y
wait_input

# Clean up
log "[!] Cleaning up..."
dnf clean all
log "[*] Script completed successfully! Press Enter to finish..."
wait_input