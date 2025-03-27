#!/bin/bash

# Exit immediately if a command fails
set -e

echo "=== Assignment 2 Script Started ==="

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root."
    exit 1
fi

## FIX NETPLAN FILE PERMISSIONS ##
echo "Fixing permissions for netplan files..."
sudo chmod 600 /etc/netplan/00-installer-config.yaml
sudo chmod 600 /etc/netplan/01-network-manager-all.yaml
echo "Permissions for netplan files fixed."

## NETWORK CONFIGURATION ##
echo "Configuring network settings..."
NETPLAN_FILE="/etc/netplan/00-installer-config.yaml"
if grep -q "192.168.16.21/24" "$NETPLAN_FILE"; then
    echo "Network already configured."
else
    cat <<EOF > $NETPLAN_FILE
network:
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.16.21/24
  version: 2
EOF
    netplan apply
    echo "Network configuration updated."
fi

# Update /etc/hosts
if grep -q "192.168.16.21 server1" /etc/hosts; then
    echo "/etc/hosts already configured."
else
    sed -i '/server1/d' /etc/hosts  # Remove old entries
    echo "192.168.16.21 server1" >> /etc/hosts
    echo "/etc/hosts updated."
fi

## INSTALL REQUIRED SOFTWARE ##
echo "Ensuring Apache2 and Squid are installed..."
apt update
apt install -y apache2 squid
systemctl enable --now apache2 squid
echo "Apache2 and Squid installed and started."

## USER ACCOUNT SETUP ##
echo "Creating user accounts..."
USERS=("kamal-hasan" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")
for user in "${USERS[@]}"; do
    if id "$user" &>/dev/null; then
        echo "User $user already exists."
    else
        useradd -m -s /bin/bash "$user"
        echo "User $user created."
    fi

    # Ensure SSH keys exist
    USER_HOME="/home/$user"
    SSH_DIR="$USER_HOME/.ssh"
    AUTH_KEYS="$SSH_DIR/authorized_keys"

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    touch "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
    chown -R "$user:$user" "$SSH_DIR"

    # Generate SSH keys for user if they do not exist
    if [[ ! -f "$SSH_DIR/id_rsa.pub" ]]; then
        sudo -u "$user" ssh-keygen -t rsa -b 4096 -f "$SSH_DIR/id_rsa" -N ""
        sudo -u "$user" ssh-keygen -t ed25519 -f "$SSH_DIR/id_ed25519" -N ""
    fi

    # Add generated public keys to authorized_keys
    cat "$SSH_DIR/id_rsa.pub" >> "$AUTH_KEYS"
    cat "$SSH_DIR/id_ed25519.pub" >> "$AUTH_KEYS"
done

## ADD USER TO SUDO GROUP ##
echo "Adding dennis to sudo group..."
usermod -aG sudo dennis

echo "=== Assignment 2 Script Completed Successfully! ==="

