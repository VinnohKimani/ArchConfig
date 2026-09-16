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

## macOS (MacBook Pro) Troubleshooting Guide

If you or a friend are trying to connect a MacBook (e.g., MacBook Pro 2015) to JKUAT's Eduroam network and it keeps failing, follow these steps to bypass common issues.

### Issue 1: Infrastructure Failure (The "Library Bug")
**Symptom:** The Mac refuses to connect or keeps asking for the password despite it being 100% correct.
**Cause:** Certain Wi-Fi Access Points on campus (notably in the library) frequently lose their connection to the main authentication server (RADIUS). When this happens, the router will instantly reject *all* devices, no matter what OS you are using.
**Solution:** 
1. Walk to a different building or classroom where you know Eduroam works (e.g., where it worked previously in the morning).
2. Connect your Mac there. If it connects perfectly, **your laptop is fine** and the issue is just broken routers in the library.

### Issue 2: Temporary Account Lockout
**Symptom:** You entered the wrong password a few times, or your phone/Mac tried to auto-connect with old credentials, and now even the correct password is rejected.
**Cause:** The university's Active Directory server will temporarily lock your student account (usually for 30 to 60 minutes) if it detects too many failed attempts.
**Solution:** 
1. Turn off Wi-Fi on all your devices (Mac, phone, tablet) so they stop spamming the server.
2. Wait at least 60 minutes for the server lockout to expire.
3. Turn Wi-Fi back on and enter the correct credentials.

### Issue 3: Stale Keychain Credentials & Certificates
macOS heavily relies on the Keychain. If it saved a corrupted certificate or an old password, it will silently fail.
**Solution:**
1. Open **System Settings** -> **Wi-Fi**.
2. Scroll down to **Advanced** or "Known Networks", find `eduroam`, and click **Remove / Forget This Network**.
3. Open the **Keychain Access** app (search it in Spotlight).
4. Search for `eduroam` in the top right. Delete any passwords or certificates related to eduroam.
5. Re-connect to `eduroam`. When prompted for credentials, use:
   - **Username:** `vincent.kimani2024@students.jkuat.ac.ke` *(or your respective student email/ID format)*
   - **Password:** Your student portal password (e.g., `sct222-0131/2024`).
6. If a "Verify Certificate" window pops up showing the JKUAT CA, click **Show Certificate**, expand the Trust section, select **Always Trust**, and click Continue.

*Alternative macOS Setup:* The easiest way to configure Eduroam perfectly on macOS is to use the official configuration profile. Connect to a mobile hotspot, go to [cat.eduroam.org](https://cat.eduroam.org/), select JKUAT, and download the Apple macOS profile. Double-click the downloaded `.mobileconfig` file to install it, enter your credentials when prompted, and it will automatically handle all security and certificate settings for you!
