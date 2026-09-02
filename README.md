# MacBook Pro 2015 - Arch Linux Fixes

## Executive Summary
This document tracks the resolution of two critical post-installation issues on a MacBook Pro 2015 running Arch Linux with Hyprland (HyDE dotfiles):
1. **Wi-Fi Connectivity Failure:** The built-in Broadcom BCM43602 Wi-Fi adapter was unable to associate with modern WPA3/WPA2 networks (resulting in a 90-second timeout loop and `NO-CARRIER` state).
2. **Hyprland Config Errors:** A red banner displaying `gestures:workspace_swipe does not exist` appeared on startup due to deprecated configuration syntax in newer Hyprland releases.

## Root Cause Analysis

### 1. Wi-Fi Connectivity
- **Incorrect Driver Assumption:** The proprietary `broadcom-wl-dkms` package does **not** support the BCM43602 chip. Attempting to use the `wl` module resulted in a complete crash during initialization (`ERROR @wl_cfg80211_detach`).
- **WPA Supplicant & MAC Randomization Bugs:** While the correct open-source driver (`brcmfmac`) was originally loaded, it failed to complete security handshakes due to two compounding issues:
  1. `NetworkManager` enables MAC address randomization by default during scanning, which breaks association on older Apple Broadcom chips.
  2. The default `wpa_supplicant` backend struggles with WPA3/SAE (and often WPA2 with Protected Management Frames) on the BCM43602.
- **Resolution:** Blacklist `wl`, restore `brcmfmac`, and switch NetworkManager's Wi-Fi backend to Intel's `iwd` while explicitly disabling MAC randomization.q

### 2. Hyprland Config Errors
- **Deprecated Syntax:** Hyprland `0.41.0+` moved the `workspace_swipe` configuration. The old `gestures:workspace_swipe` variables were triggering parsing errors.
- **Resolution:** Remove the deprecated variables from `~/.config/hypr/userprefs.conf`. (These were cleared out, and `hyprctl reload` was issued to flush the error banner).

---

## Exact Step-by-Step Resolution Guide

### Step 1: Fix Kernel Module Blacklists
Ensure the crashed proprietary driver is blacklisted and the correct open-source driver is prioritized.

```bash
sudo tee /etc/modprobe.d/blacklist-broadcom.conf > /dev/null << 'EOF'
blacklist b43
blacklist b43legacy
blacklist bcma
blacklist wl
EOF
```

### Step 2: Switch NetworkManager to `iwd`
Configure NetworkManager to use `iwd` instead of `wpa_supplicant`, and disable broken MAC randomization.

```bash
sudo tee /etc/NetworkManager/conf.d/wifi_backend.conf > /dev/null << 'EOF'
[device]
wifi.backend=iwd
wifi.scan-rand-mac-address=no
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
Reload the networking stack to apply the new backend and driver:

```bash
sudo rmmod wl
sudo modprobe brcmfmac
sudo systemctl enable --now iwd
sudo systemctl restart NetworkManager
```

---

## Reboot Persistence Verification Checklist

To guarantee that the network connection survives a system reboot, the following checks have been verified:

- [x] **Services Enabled:** Both `NetworkManager` and `iwd` are enabled to start on boot.
  - *Verify with:* `systemctl is-enabled NetworkManager iwd` (Should output `enabled` for both).
- [x] **Kernel Module Persistence:** The blacklisting of the bad `wl` module is permanently saved in `/etc/modprobe.d/blacklist-broadcom.conf`.
  - *Verify with:* `cat /etc/modprobe.d/blacklist-broadcom.conf`
- [x] **NetworkManager Configs:** The backend override (`wifi_backend.conf`) is permanently stored in `/etc/NetworkManager/conf.d/`.

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

---

## 3. Battery Notification System Fixes

### Symptoms
1. **Notification Spam (Jitter):** A physically degraded battery caused rapid oscillation between "Charging" and "Discharging" states near full charge, spamming notifications.
2. **Incorrect Percentage:** The battery notification showed ~22% when plugged/unplugged, while Waybar and the desktop environment correctly showed ~72%.
3. **10-Second Status Lag:** When physically plugging or unplugging the MagSafe charger, both Waybar and the notifications took ~10 seconds to respond.

### Root Causes
- **Apple SMC Sysfs Capacity Bug:** On MacBooks, the kernel (`/sys/class/power_supply/BAT0/capacity`) calculates the percentage relative to the *factory original design capacity*, rather than the *current degraded usable capacity*. This resulted in an artificially low reading in the notification script.
- **Apple SMC Status Lag:** The internal battery controller takes 10-15 seconds to fully transition states and report it to `sysfs BAT0`. 
- **Waybar/DBus Polling:** Waybar and the `batterynotify.sh` script were strictly watching the lagging battery state instead of the instantaneously updating AC adapter pin state (`ADP1`).

### Resolutions
1. **Accurate Percentage (upower):** Modified `~/.local/lib/hyde/batterynotify.sh`'s `get_battery_info()` function to fetch the percentage from `upower` instead of the raw `sysfs` file, ensuring parity with the desktop environment.
2. **Instant Status Updates (Waybar & Script):**
   - **Waybar:** Added `"adapter": "ADP1"` to `~/.local/share/waybar/modules/battery.jsonc` so the icon updates instantly on physical cable events.
   - **Script:** Updated the `dbus-monitor` listener to monitor `line_power` events. Added an override in `get_battery_info()` to read `/sys/class/power_supply/ADP1/online` and bypass the 10-second SMC lag instantly.
3. **Smart Hysteresis Noise Filter:** Added a 60-second, 2%-threshold debouncing filter to `batterynotify.sh` to completely silence sensor jitter. Crucially, added a tracker for the physical AC adapter pin state (`last_adp_online`) to **bypass** the filter entirely whenever the user physically touches the cable.

---

## 4. Keyboard Backlight Fixes

### Symptoms
1. **Unresponsive Keys:** The keyboard backlight keys (`F5` and `F6`) on the MacBook Pro 2015 did not adjust the keyboard illumination. 

### Root Causes
- **Missing Keybindings:** While the `applesmc` driver correctly exposes the keyboard backlight to the kernel via `/sys/class/leds/smc::kbd_backlight/`, there were no specific `bind` mappings inside the Hyprland configuration to capture `XF86KbdBrightnessUp` and `XF86KbdBrightnessDown` and dispatch a brightness change command.

### Resolutions
1. **Added Keybindings:** Verified that `brightnessctl` could control `smc::kbd_backlight` without `sudo` privileges. Added repeating keybindings (`bindel`) to `~/.config/hypr/userprefs.conf` for the keyboard backlight keys:
   ```conf
   # Keyboard Backlight
   bindel = , XF86KbdBrightnessUp, exec, brightnessctl --device='smc::kbd_backlight' set +10%
   bindel = , XF86KbdBrightnessDown, exec, brightnessctl --device='smc::kbd_backlight' set 10%-
   ```

---

## 5. Trackpad Fixes (Tap-and-Drag)

### Symptoms
Accidental text highlighting and dragging of browser tabs when gently tapping the trackpad on the MacBook Pro.

### Root Cause
Hyprland's `tap-and-drag` feature is overly sensitive on MacBook trackpads, interpreting a slight finger roll during a tap as a click-and-hold drag event.

### Resolution
Disabled `tap-and-drag` in the Hyde dotfiles configuration.
- **File:** `~/.config/hypr/userprefs.conf`
- **Change:** Set `tap-and-drag = false` in the `input { touchpad { ... } }` block.
- **Command:** `sed -i 's/tap-and-drag = true/tap-and-drag = false/' ~/.config/hypr/userprefs.conf`

---

## 6. Battery Degradation & Sudden Shutdowns

### Symptoms
The MacBook completely shuts down without warning, despite the battery indicator showing 20-40% remaining. The system also fails to send a low battery notification before dying.

### Root Cause
Severe hardware degradation of the lithium-ion battery. Diagnostic (`upower -i /org/freedesktop/UPower/devices/battery_BAT0`) revealed:
- **Charge Cycles:** 1,863 (Apple recommends replacement at 1,000).
- **Battery Health:** 33.0% of original design capacity.
When heavily degraded batteries are put under load, they suffer from extreme "voltage sag". The voltage drops instantly below the laptop's minimum operating threshold, causing a hard power cut before the OS has time to trigger a 10% or 5% warning notification.

### Resolution
This is a **hardware limitation**. Software configuration cannot prevent voltage sag on a worn-out battery. The MacBook must remain plugged in or the battery must be physically replaced.

---

## 7. System Stability (OOM Crashes & Swap Space)

### Symptoms
Heavy applications (like VS Code / Antigravity IDE) terminate unexpectedly during heavy workloads (e.g., running language servers). System logs (`journalctl`) show an `Out of memory: Killed process` (OOM kill) event.

### Root Cause
The 2015 MacBook Pro is hard-limited to 8GB of soldered RAM. By default, Arch Linux relies heavily on physical RAM and `zram` (compressed memory). When both fill up, Linux lacks a fallback SSD swap file (which macOS sets up dynamically by default), resulting in the kernel forcefully killing the heaviest application to save the system from freezing.

### Resolution
Created an 8GB SSD Swap File to act as emergency fallback memory, mimicking macOS's dynamic pager.

**Step-by-Step Commands (for ext4 filesystems):**
1. `sudo dd if=/dev/zero of=/swapfile bs=1M count=8192 status=progress`
2. `sudo chmod 600 /swapfile`
3. `sudo mkswap /swapfile`
4. `sudo swapon /swapfile`
5. `echo '/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab`

---

## 8. IDE Terminal Font Fix (Broken Icons)

### Symptoms
The integrated terminal inside VS Code/Antigravity shows broken square boxes (`[X]`) instead of icons (like folders, Git branches, or language logos), while the standalone terminal emulator displays them correctly.

### Root Cause
The ZSH shell prompt (e.g., Powerlevel10k/Starship) relies on "Nerd Fonts" to render custom icons. The IDE's default integrated terminal font does not support these glyphs.

### Resolution
Update the IDE settings to use an installed Nerd Font.
- **Settings Path:** `Terminal > Integrated: Font Family`
- **Value:** `'JetBrainsMono Nerd Font'` (or another installed Nerd Font found via `fc-list | grep -i "nerd"`).

---

## 9. Arch Linux Package Management (pacman vs yay)

### Overview
- **`pacman`**: The official Arch Linux package manager. Used to install pre-compiled, officially supported software.
- **`yay` (Yet Another Yogurt)**: An AUR (Arch User Repository) helper. It acts as a wrapper around `pacman` but adds the superpower to download, compile, and install community-maintained software (like `antigravity-ide` or `brave-bin`).
- **Best Practice:** Use `yay` for everyday usage, as it seamlessly handles both official and AUR packages (`yay -Syu` updates everything).

### Troubleshooting AUR Builds
If a large AUR package (like Brave or an IDE) finishes building but fails to install with a `sudo: timed out reading password` error, it means the compilation took longer than the default `sudo` timeout. 
- **Fix:** Simply rerun the install command (`yay -Syu`). The packages are already cached locally (`~/.cache/yay/`), so it will skip compilation and instantly prompt for the password to install.

---

## 10. Installed Applications & Development Environment

To make future installations seamless, here is a categorized list of the explicit packages installed on this system.

### 💻 IDEs & Development Tools
- `antigravity-ide` (Primary IDE)
- `visual-studio-code-bin` (Fallback IDE)
- `neovim` / `vim` (Terminal editors)
- `docker` / `docker-compose` (Containerization)
- `git` / `github-cli` (Version Control)
- `ngrok` (Tunneling)

### ⚙️ Programming Languages & Runtimes
- **JavaScript/TypeScript:** `nodejs`, `npm`, `bun`
- **Python:** `pyenv`, `python-pipenv`, `python-pipx`, `uv`
- **Rust/C++:** `rust`, `base-devel`, `cmake`, `ninja`

### 🌐 Web Browsers
- `brave-bin`
- `firefox`

### 🎨 Desktop Environment (Hyprland / Hyde)
- **Core:** `hyprland`, `hyprlock`, `hypridle`, `hyprsunset`, `hyprpicker`, `hyprpolkitagent`
- **UI Components:** `waybar`, `rofi`, `wlogout`, `dunst`, `kitty` (Terminal)
- **Display Manager:** `sddm`

### 🛠️ CLI Utilities & System Tools
- **Shell:** `zsh`, `starship` (Prompt)
- **System Monitors:** `btop`, `htop`, `fastfetch`
- **File & Search:** `fzf`, `bat`, `tree`, `jq`, `unzip`, `wget`
- **Performance:** `zram-generator` (RAM compression/swap)

### 🚀 One-Liner Reinstall Command
For your next Arch installation, after installing `yay`, you can run this command to restore your entire development environment and application suite at once:

```bash
yay -S antigravity-ide visual-studio-code-bin neovim docker docker-compose git github-cli ngrok nodejs npm bun pyenv python-pipenv python-pipx uv rust base-devel cmake ninja brave-bin firefox hyprland hyprlock hypridle hyprsunset hyprpicker hyprpolkitagent waybar rofi wlogout dunst kitty sddm zsh starship btop fastfetch fzf bat tree jq zram-generator
```
