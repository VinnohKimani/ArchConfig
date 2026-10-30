# Eduroam Configuration for JKUAT (Arch Linux)

This folder contains the configuration files required to connect to the `eduroam` WPA2-Enterprise Wi-Fi network at JKUAT on Arch Linux.

> **Current state of this machine:** NetworkManager runs the `wpa_supplicant` backend, not `iwd`. `iwd` was removed because its DHCP backend conflicted with NetworkManager and kept dropping the link (see Phase 4 in [../CHANGELOG.md](../CHANGELOG.md)). The normal way to join Eduroam today is a native NetworkManager WPA-EAP profile (PEAP/MSCHAPv2) with the password kept in the NetworkManager secret store — no plaintext file on disk.
>
> The `iwd` material in this folder is kept as an **isolated diagnostic path**: it tests whether the credential/certificate pair itself works, independent of NetworkManager. Do not re-enable `iwd` as the NetworkManager backend.

## Files in this Directory

- `eduroam.8021x`: `iwd` profile template (PEAP/MSCHAPv2) used by the diagnostic route. Contains placeholders only.
- `jkuat_ca.pem`: JKUAT RADIUS CA certificate used for server validation.
- `install_eduroam.sh`: Installs the `iwd` profile into `/var/lib/iwd/` with root-only (`0600`) permissions. It takes your identity from `EDUROAM_IDENTITY` and prompts for the password — **no credential is stored in the script**.
- `claude_diagnostics.sh`: Isolated diagnostic that tests native `iwd` connectivity without permanently altering NetworkManager. It temporarily pauses NetworkManager's control of `wlan0`, connects using `iwd`, prints the connection logs, and then cleans up.
- `claude_diagnostics_2.sh`: Second-pass variant for association/DHCP failures.

### Using the Diagnostic Script

If you are encountering persistent issues with NetworkManager and Eduroam, you can use `claude_diagnostics.sh` to isolate the problem to `iwd`.

1. Run it with the credentials in the environment — do not paste them into the file:
   ```bash
   sudo EDUROAM_IDENTITY='you@students.jkuat.ac.ke' ./claude_diagnostics.sh
   ```
2. The script will output raw connection logs.
3. Never commit real credentials: this repository is public and git history keeps what you remove.

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
   - **Username:** `your_student_id@students.jkuat.ac.ke` (use your own student email/ID format)
   - **Password:** your student portal password.
6. If a "Verify Certificate" window pops up showing the JKUAT CA, click **Show Certificate**, expand the Trust section, select **Always Trust**, and click Continue.

*Alternative macOS Setup:* The easiest way to configure Eduroam perfectly on macOS is to use the official configuration profile. Connect to a mobile hotspot, go to [cat.eduroam.org](https://cat.eduroam.org/), select JKUAT, and download the Apple macOS profile. Double-click the downloaded `.mobileconfig` file to install it, enter your credentials when prompted, and it will automatically handle all security and certificate settings for you!
