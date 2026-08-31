# Eduroam Configuration for JKUAT (Arch Linux)

This folder contains the configuration files required to successfully connect to the `eduroam` WPA2-Enterprise Wi-Fi network at JKUAT using `iwd` (iNet Wireless Daemon).

Since `NetworkManager` is configured to use the `iwd` backend on this machine, using NetworkManager's GUI for enterprise connections can sometimes glitch out and modify backend settings incorrectly (which previously caused system-wide Wi-Fi failures). 

By supplying the configuration directly to `iwd`, we bypass any GUI bugs and ensure a seamless, native connection.

## Files in this Directory

- `eduroam.8021x`: The template configuration file that `iwd` reads to understand the security protocols (PEAP/MSCHAPV2) and your credentials.
- `install_eduroam.sh`: A helper script that safely copies the configuration into the protected system directory (`/var/lib/iwd/`) with the correct permissions.

## How to Set It Up

### Step 1: Add Your Credentials
Open the `eduroam.8021x` file in your preferred text editor.
Find the following lines and replace the placeholder text with your actual JKUAT credentials:
```ini
EAP-PEAP-Phase2-Identity=your_student_id@jkuat.ac.ke
EAP-PEAP-Phase2-Password=your_password
```
*(Note: Do not change the outer `EAP-Identity=anonymous@jkuat.ac.ke` unless JKUAT specifically requires it to be your actual email).*

### Step 2: Install the Profile
Run the installer script. Because `iwd` configuration files contain plain-text passwords, the system directory requires root access (`sudo`) to protect it.

```bash
sudo ./install_eduroam.sh
```
This script will copy the file to `/var/lib/iwd/eduroam.8021x`, lock down its read permissions, and restart the `iwd` service.

### Step 3: Connect
The next time you are on campus and in range of the `eduroam` network, `iwd` should automatically authenticate and connect in the background!

## Troubleshooting CA Certificates

In some instances, the university RADIUS server refuses the connection unless you explicitly validate their Certificate Authority (CA). If the connection fails silently after completing Steps 1 and 2:

1. Download the JKUAT CA Certificate (`JKUAT_CA.pem`) from the university's IT portal or from `cat.eduroam.org`.
2. Move it to a secure location (e.g., `/etc/ssl/certs/JKUAT_CA.pem`).
3. Open `eduroam.8021x` and uncomment the CA Certificate line:
   ```ini
   EAP-PEAP-CACert=/etc/ssl/certs/JKUAT_CA.pem
   ```
4. Run `sudo ./install_eduroam.sh` again to apply the updated configuration.
