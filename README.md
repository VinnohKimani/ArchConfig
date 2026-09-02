# MacBook Pro 2015 - Arch Linux Wi-Fi Fixes

## Executive Summary
This document tracks the resolution of a critical post-installation issue on a MacBook Pro 2015 running Arch Linux with Hyprland (HyDE dotfiles):
1. **Wi-Fi Connectivity Failure:** The built-in Broadcom BCM43602 Wi-Fi adapter was unable to associate with modern WPA3/WPA2 networks (resulting in a 90-second timeout loop and `NO-CARRIER` state).

*(For other system tweaks like battery notifications, Hyprland fixes, and terminal fonts, see [SYSTEM_CONFIGS.md](SYSTEM_CONFIGS.md)).*

## Root Cause Analysis

### 1. Wi-Fi Connectivity
- **Hardware Limitations & Firmware Bugs:** The built-in Broadcom BCM43602 uses the `brcmfmac` open-source driver, but firmware bugs cause issues with roaming, offloading, and WPA3 security handshakes, resulting in association timeouts.
- **NetworkManager MAC Randomization:** `NetworkManager` enables MAC address randomization by default during scanning and connection, which further breaks association on this older Apple Broadcom chip.
- **Resolution:** Configure the `brcmfmac` module to disable problematic hardware features (`feature_disable=0x82000`) and explicitly disable all MAC randomization in NetworkManager.

---

## Exact Step-by-Step Resolution Guide

### Step 1: Configure `brcmfmac` Kernel Module
Pass the `feature_disable=0x82000` flag to the `brcmfmac` driver to disable problematic offloading and roaming features that break connectivity.

```bash
sudo tee /etc/modprobe.d/brcmfmac.conf > /dev/null << 'EOF'
options brcmfmac feature_disable=0x82000
EOF
```

### Step 2: Disable NetworkManager MAC Randomization
Explicitly disable MAC randomization for both scanning and connection profiles to allow association with access points.

```bash
sudo tee /etc/NetworkManager/conf.d/mac-rand.conf > /dev/null << 'EOF'
[device]
wifi.scan-rand-mac-address=no

[connection]
wifi.cloned-mac-address=preserve
wifi.mac-address-randomization=1
EOF
```

### Step 3: Ensure Wi-Fi Power Saving is Disabled (Optional but Recommended)
To prevent dropouts on the MacBook Pro 2015 when running on battery, explicitly disable Wi-Fi power saving:

```bash
sudo tee /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf > /dev/null << 'EOF'
[connection]
wifi.powersave = 2
EOF
```

### Step 4: Apply Changes and Reload Services
Reload the kernel module and the networking stack to apply the changes:

```bash
sudo modprobe -r brcmfmac
sudo modprobe brcmfmac
sudo systemctl restart NetworkManager
```

---

## Reboot Persistence Verification Checklist

To guarantee that the network connection survives a system reboot, the following checks have been verified:

- [x] **Services Enabled:** `NetworkManager` is enabled to start on boot.
  - *Verify with:* `systemctl is-enabled NetworkManager`
- [x] **Kernel Module Configuration:** The `brcmfmac` feature disable flag is permanently saved in `/etc/modprobe.d/brcmfmac.conf`.
  - *Verify with:* `cat /etc/modprobe.d/brcmfmac.conf`
- [x] **NetworkManager Configs:** MAC randomization and powersave configs are permanently stored in `/etc/NetworkManager/conf.d/`.

---

## Hardware Status Verification Commands

Use these commands if troubleshooting is needed in the future:

* **Check PCI Wi-Fi Controller:** 
  `lspci -nnk | grep -i network -A 3`
  *(Ensure `brcmfmac` is listed as the kernel driver in use).*
* **Check Wi-Fi Interface State:** 
  `ip link show wlan0`
  *(Look for state `UP`).*
* **Check Hardware/Software Blocks:** 
  `rfkill list all`
  *(Ensure Wireless LAN is neither soft nor hard blocked).*
* **Scan for Networks:** 
  `nmcli device wifi rescan && sleep 3 && nmcli device wifi list`
