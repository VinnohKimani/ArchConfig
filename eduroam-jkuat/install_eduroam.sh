#!/bin/bash
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo."
  exit 1
fi

PROFILE_SOURCE="/home/vinnoh/eduroam.8021x"
PROFILE_DEST="/var/lib/iwd/eduroam.8021x"

if [ ! -f "$PROFILE_SOURCE" ]; then
    echo "Error: $PROFILE_SOURCE not found!"
    exit 1
fi

echo "Copying eduroam profile to iwd directory..."
cp "$PROFILE_SOURCE" "$PROFILE_DEST"

echo "Securing profile permissions (passwords are stored here)..."
chmod 600 "$PROFILE_DEST"

echo "Restarting iwd to load the new profile..."
systemctl restart iwd

echo "Done! iwd should now automatically attempt to connect to eduroam when in range."
