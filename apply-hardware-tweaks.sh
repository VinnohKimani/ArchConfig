#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/home/vinnoh/Development/ArchConfig"

echo "[1/5] Installing SPI ACPI keyboard/trackpad wakeup service..."
install -m 0644 "$REPO_DIR/macbook-wakeup.service" /etc/systemd/system/macbook-wakeup.service
systemctl daemon-reload
systemctl enable --now macbook-wakeup.service
# Run wake toggle immediately if needed
if grep -q 'SPIT.*disabled' /proc/acpi/wakeup; then
    echo SPIT > /proc/acpi/wakeup
fi

echo "[2/5] Configuring Bluetooth USB autosuspend fix..."
install -m 0644 "$REPO_DIR/btusb.conf" /etc/modprobe.d/btusb.conf

echo "[3/5] Configuring Broadcom Wi-Fi offload fix..."
install -m 0644 "$REPO_DIR/brcmfmac.conf" /etc/modprobe.d/brcmfmac.conf

echo "[4/5] Disabling Wi-Fi scan MAC address randomization in NetworkManager..."
mkdir -p /etc/NetworkManager/conf.d
install -m 0644 "$REPO_DIR/mac-rand.conf" /etc/NetworkManager/conf.d/mac-rand.conf
systemctl reload NetworkManager || true

echo "[5/5] Configuring power button protection in systemd-logind..."
mkdir -p /etc/systemd/logind.conf.d
install -m 0644 "$REPO_DIR/ignore-power-key.conf" /etc/systemd/logind.conf.d/ignore-power-key.conf
kill -s HUP $(pidof systemd-logind)

echo "=== All 5 hardware tweaks successfully applied! ==="
