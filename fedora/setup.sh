#!/bin/bash

LOGFILE="/var/log/install_script.log"
exec > >(tee -a "$LOGFILE") 2>&1

if [[ $UID != 0 ]]; then
    echo "Please run this script with sudo:"
    echo "sudo $0 $*"
    exit 1
fi

# Function to check and install a package
install_package() {
    local pkg=$1
    if ! dnf -q list installed "$pkg" &>/dev/null; then
        echo "Installing $pkg..."
        if ! dnf install -y "$pkg"; then
            echo "Failed to install $pkg. Exiting."
            exit 1
        fi
    else
        echo "$pkg is already installed."
    fi
}

# Define initial packages
initpackages=(
    "neovim" "git" "fish" "tmux" "net-tools" "bat"
)

# Define server-specific packages
serverpackages=(
    "nginx" "httpd" "php" "mariadb-server"
    # "sqlite"  # Uncomment if you want to install SQLite
)

# Update system
echo "[!] Updating system..."
dnf update -y
echo "[*] System updated. Press Enter to continue..."
read -r

# Install initial packages
echo "[!] Installing initial packages..."
for pkg in "${initpackages[@]}"; do
    install_package "$pkg"
done
echo "[*] Initial packages installed. Press Enter to continue..."
read -r

# Install server-specific packages
echo "[!] Installing server-specific packages..."
for pkg in "${serverpackages[@]}"; do
    install_package "$pkg"
done
echo "[*] Server-specific packages installed. Press Enter to continue..."
read -r

# Check and install firewalld if not installed
echo "[!] Configuring firewall..."
if ! dnf -q list installed firewalld &>/dev/null; then
    echo "Installing firewalld..."
    dnf install -y firewalld
else
    echo "firewalld is already installed."
fi
echo "[*] Firewall configured. Press Enter to continue..."
read -r

# Enable and start necessary services
echo "[!] Enabling and starting services..."
systemctl enable httpd
systemctl start httpd
systemctl enable mariadb
systemctl start mariadb
systemctl enable nginx
systemctl start nginx
systemctl enable --now firewalld
echo "[*] Services enabled and started. Press Enter to continue..."
read -r

# Allow SSH and other necessary services through the firewall
echo "[!] Allowing necessary services through the firewall..."
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-service=mysql
firewall-cmd --reload
echo "[*] Firewall rules updated. Press Enter to continue..."
read -r

# Set Fish as the default shell
echo "[!] Setting Fish as the default shell for the user..."
if command -v fish &>/dev/null; then
    chsh -s "$(command -v fish)"
    if [[ $? -eq 0 ]]; then
        echo "Fish has been set as the default shell."
    else
        echo "Failed to set Fish as the default shell. You may need to log out and log back in."
    fi
else
    echo "Fish is not installed. Cannot set as default shell."
fi
echo "[*] Shell configuration completed. Press Enter to continue..."
read -r

# Cleanup unused packages
echo "[!] Cleaning up unused packages..."
dnf autoremove -y
echo "[*] Unused packages removed. Press Enter to continue..."
read -r

# Clean up
echo "[!] Cleaning up..."
dnf clean all
echo "[*] Script completed successfully! Press Enter to finish..."
read -r
