#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/home/vinnoh/Development/ArchConfig"

echo "[1/5] Configuring ZRAM (lz4, ram, priority 100)..."
install -m 0644 "$REPO_DIR/zram-generator.conf" /etc/systemd/zram-generator.conf
# Switch live zram0 to lz4 if possible, or reload zram service
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

echo "[3/5] Applying /etc/sysctl.d/99-vm.conf and enabling systemd-oomd..."
install -m 0644 "$REPO_DIR/99-vm.conf" /etc/sysctl.d/99-vm.conf
sysctl --system >/dev/null
systemctl enable --now systemd-oomd.service

echo "[4/5] Installing CS4208 Dual-Speaker/Bass Woofer (0x12 + 0x13) HDA Firmware Patch..."
mkdir -p /usr/lib/firmware /etc/modprobe.d
install -m 0644 "$REPO_DIR/cs4208-mbp121.fw" /usr/lib/firmware/cs4208-mbp121.fw
install -m 0644 "$REPO_DIR/alsa-macbook.conf" /etc/modprobe.d/alsa-macbook.conf

# Install and run the CS4208 Woofer Enabler script & systemd service
install -m 0755 "$REPO_DIR/enable-cs4208-woofers.py" /usr/local/bin/enable-cs4208-woofers.py
echo 0 > /sys/module/snd_hda_intel/parameters/power_save 2>/dev/null || true
/usr/local/bin/enable-cs4208-woofers.py

cat << 'EOF' > /etc/systemd/system/macbook-cs4208-woofers.service
[Unit]
Description=Enable Cirrus Logic CS4208 Bass Woofers (Node 0x04 / Pin 0x13) on MacBookPro12,1
After=sound.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/enable-cs4208-woofers.py
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target sleep.target
EOF
systemctl daemon-reload
systemctl enable --now macbook-cs4208-woofers.service

echo "[5/5] Done!"
