#!/bin/bash

LOGFILE="/var/log/install_script.log"
exec > >(tee -a "$LOGFILE") 2>&1

if [[ $UID != 0 ]]; then
    echo "Please run this script with sudo:"
    echo "sudo $0 $*"
    exit 1
fi

# Function to log messages
log() {
    echo "$1"
}

# Function to wait for user input
wait_for_input() {
    echo "Press Enter to continue..."
    read -r
}

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
wait_for_input

# Install packages
log "[!] Installing packages..."
for pkg in "${packages[@]}"; do
    install_package "$pkg"
done
wait_for_input

# Check and install firewalld if not installed
if ! dnf -q list installed firewalld &>/dev/null; then
    log "Installing firewalld..."
    dnf install -y firewalld
    log "firewalld installed successfully."
else
    log "firewalld is already installed."
fi
wait_for_input

# Enable and start necessary services
log "[!] Enabling and starting services..."
for service in "${services[@]}"; do
    systemctl enable "$service"
    systemctl start "$service"
done
systemctl enable --now firewalld
wait_for_input

# Allow necessary services through the firewall
log "[!] Allowing necessary services through the firewall..."
for fw_service in "${firewall_services[@]}"; do
    firewall-cmd --permanent --add-service="$fw_service"
done
firewall-cmd --reload
wait_for_input

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
wait_for_input

# Cleanup unused packages
log "[!] Cleaning up unused packages..."
dnf autoremove -y
wait_for_input

# Clean up
log "[!] Cleaning up..."
dnf clean all
log "[*] Script completed successfully! Press Enter to finish..."
wait_for_input
