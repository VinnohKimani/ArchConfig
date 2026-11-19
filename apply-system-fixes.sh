#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/home/vinnoh/Development/ArchConfig"

echo "[1/5] Configuring ZRAM (lz4, ram / 2 (~3.85GB), priority 100)..."
install -m 0644 "$REPO_DIR/zram-generator.conf" /etc/systemd/zram-generator.conf
swapoff /dev/zram0 2>/dev/null || true
systemctl daemon-reload
systemctl restart systemd-zram-setup@zram0.service || swapon -p 100 /dev/zram0 || true

echo "[2/5] Creating and activating 8 GiB /swapfile (priority 10)..."
if [[ ! -f /swapfile ]]; then
    dd if=/dev/zero of=/swapfile bs=1M count=8192 status=none
    chmod 0600 /swapfile
    mkswap /swapfile
fi
chmod 0600 /swapfile
swapon -p 10 /swapfile 2>/dev/null || true
if ! grep -q '^/swapfile' /etc/fstab; then
    printf '\n# 8 GiB SSD Overflow Swapfile (Tier-2 behind ZRAM)\n/swapfile none swap defaults,pri=10 0 0\n' >> /etc/fstab
fi

echo "[3/5] Applying /etc/sysctl.d/99-vm.conf (swappiness=60, watermark_scale_factor=20)..."
install -m 0644 "$REPO_DIR/99-vm.conf" /etc/sysctl.d/99-vm.conf
sysctl --system >/dev/null
systemctl enable --now systemd-oomd.service

echo "[4/5] Installing CS4208 Dual-Speaker/Bass Woofer HDA Firmware & Sleep Resiliency..."
mkdir -p /usr/lib/firmware /etc/modprobe.d /usr/lib/systemd/system-sleep
install -m 0644 "$REPO_DIR/cs4208-mbp121.fw" /usr/lib/firmware/cs4208-mbp121.fw
install -m 0644 "$REPO_DIR/alsa-macbook.conf" /etc/modprobe.d/alsa-macbook.conf

# Install woofer enabler script
install -m 0755 "$REPO_DIR/enable-cs4208-woofers.py" /usr/local/bin/enable-cs4208-woofers.py

# Install systemd suspend/resume sleep hook to persist woofers across sleep/wake cycles
install -m 0755 "$REPO_DIR/cs4208-woofers-sleep.sh" /usr/lib/systemd/system-sleep/cs4208-woofers.sh

echo 0 > /sys/module/snd_hda_intel/parameters/power_save 2>/dev/null || true

# Systemd boot service
cat << 'EOF' > /etc/systemd/system/macbook-cs4208-woofers.service
[Unit]
Description=Enable Cirrus Logic CS4208 Bass Woofers (Node 0x04 / Pin 0x13) on MacBookPro12,1
After=sound.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/enable-cs4208-woofers.py

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now macbook-cs4208-woofers.service

# Run live activation immediately
/usr/local/bin/enable-cs4208-woofers.py || true

echo "[5/5] Updating user volume control script..."
if [[ -d "/home/vinnoh/.local/lib/hyde" ]]; then
    install -m 0755 "$REPO_DIR/volumecontrol.sh" /home/vinnoh/.local/lib/hyde/volumecontrol.sh
fi

echo "=== System fixes successfully applied! ==="
