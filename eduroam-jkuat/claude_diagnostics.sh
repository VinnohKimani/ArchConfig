#!/bin/bash
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo."
  exit 1
fi

echo "--- Regenerating the file to capture Claude's requested info ---"
nmcli device set wlan0 managed no
sleep 1

cat <<'INNER_EOF' > /var/lib/iwd/eduroam.8021x
[Security]
EAP-Method=PEAP
EAP-Identity=anonymous@jkuat.ac.ke
EAP-PEAP-Phase2-Method=MSCHAPV2
EAP-PEAP-Phase2-Identity=vincent.kimani2024@students.jkuat.ac.ke
EAP-PEAP-Phase2-Password=sct222-0131/2024
INNER_EOF

chown root:root /var/lib/iwd/eduroam.8021x
chmod 600 /var/lib/iwd/eduroam.8021x

echo "--- STEP 1 & 2: Checking directory and file ---"
ls -ld /var/lib/iwd
ls -l /var/lib/iwd/eduroam.8021x
stat /var/lib/iwd/eduroam.8021x
cat -A /var/lib/iwd/eduroam.8021x | sed 's/sct222-0131\/2024/[REDACTED]/g'
hexdump -C /var/lib/iwd/eduroam.8021x | head -10

echo ""
echo "--- Attempting Connection ---"
systemctl restart iwd
sleep 2
iwctl station wlan0 connect eduroam
sleep 3
journalctl -u iwd -n 25 --no-pager

rm -f /var/lib/iwd/eduroam.8021x
nmcli device set wlan0 managed yes
