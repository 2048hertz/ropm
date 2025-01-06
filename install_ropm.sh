#!/bin/bash

# ROPM (RObert Package Manager) Installer
# Written by Ayaan Eusufzai
# Starting date: 6th January, 2025

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

echo "Installing ROPM"
cp ropm.sh /usr/local/bin/ropm
chmod +x /usr/local/bin/ropm


echo "Installation complete!"
echo "Use 'ropm' to access the RObert Package Manager."


