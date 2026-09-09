# MacBook Pro 2015 - System Tweaks & Fixes

## 1. Hyprland Config Errors

### Symptoms
A red banner displaying `gestures:workspace_swipe does not exist` appeared on startup due to deprecated configuration syntax in newer Hyprland releases.

### Root Cause
- **Deprecated Syntax:** Hyprland `0.41.0+` moved the `workspace_swipe` configuration. The old `gestures:workspace_swipe` variables were triggering parsing errors.

### Resolution
- **Resolution:** Remove the deprecated variables from `~/.config/hypr/userprefs.conf`. (These were cleared out, and `hyprctl reload` was issued to flush the error banner).

---

## 2. Battery Notification System Fixes

### Symptoms
1. **Notification Spam (Jitter):** A physically degraded battery caused rapid oscillation between "Charging" and "Discharging" states near full charge, spamming notifications.
2. **Incorrect Percentage:** The battery notification showed ~22% when plugged/unplugged, while Waybar and the desktop environment correctly showed ~72%.
3. **10-Second Status Lag:** When physically plugging or unplugging the MagSafe charger, both Waybar and the notifications took ~10 seconds to respond.

### Root Causes
- **Apple SMC Sysfs Capacity Bug:** On MacBooks, the kernel (`/sys/class/power_supply/BAT0/capacity`) calculates the percentage relative to the *factory original design capacity*, rather than the *current degraded usable capacity*. This resulted in an artificially low reading in the notification script.
- **Apple SMC Status Lag:** The internal battery controller takes 10-15 seconds to fully transition states and report it to `sysfs BAT0`. 
- **Waybar/DBus Polling:** Waybar and the `batterynotify.sh` script were strictly watching the lagging battery state instead of the instantaneously updating AC adapter pin state (`ADP1`).

### Resolutions
1. **Instant Charger Detection (udevadm):** Apple SMC takes 10-15 seconds to update the `BAT0/status` file. Created a custom active daemon (`~/.local/bin/battery-monitor.sh`) that uses `udevadm monitor -s power_supply` to instantly detect charger plug/unplug events and immediately trigger the notification script. This daemon is launched on boot via `~/.config/hypr/userprefs.conf`.
2. **Accurate Hardware States:** The notification script `~/.local/bin/battery-notify.sh` now reads the physical AC pin state directly from `/sys/class/power_supply/ADP1/online` instead of relying on the laggy battery status, guaranteeing 0-latency plug-in notifications.
3. **Polling Updates & Clean UI:** The script runs regular interval checks every 10 minutes for discharging updates. Standard system symbolic icons (like `battery-full-charging-symbolic`) are used via `notify-send -i` to keep the UI clean without relying on raw text emojis.

---

## 3. Keyboard Backlight Fixes

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
2. **Keyboard Backlight Sleep Timeout:** Hooked into the DPMS listener in `~/.config/hypr/hypridle.conf` to automatically save and turn off the keyboard backlight when the screen goes to sleep (300 seconds), and seamlessly restore the original brightness upon wake.

---

## 4. Trackpad Fixes (Tap-and-Drag)

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

## 5. Battery Degradation & Sudden Shutdowns

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

## 6. System Stability (OOM Crashes & Swap Space)

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

## 7. IDE Terminal Font Fix (Broken Icons)

### Symptoms
The integrated terminal inside VS Code/Antigravity shows broken square boxes (`[X]`) instead of icons (like folders, Git branches, or language logos), while the standalone terminal emulator displays them correctly.

### Root Cause
The ZSH shell prompt (e.g., Powerlevel10k/Starship) relies on "Nerd Fonts" to render custom icons. The IDE's default integrated terminal font does not support these glyphs.

### Resolution
Update the IDE settings to use an installed Nerd Font.
- **Settings Path:** `Terminal > Integrated: Font Family`
- **Value:** `'JetBrainsMono Nerd Font'` (or another installed Nerd Font found via `fc-list | grep -i "nerd"`).

---

## 8. Arch Linux Package Management (pacman vs yay)

### Overview
- **`pacman`**: The official Arch Linux package manager. Used to install pre-compiled, officially supported software.
- **`yay` (Yet Another Yogurt)**: An AUR (Arch User Repository) helper. It acts as a wrapper around `pacman` but adds the superpower to download, compile, and install community-maintained software (like `antigravity-ide` or `brave-bin`).
- **Best Practice:** Use `yay` for everyday usage, as it seamlessly handles both official and AUR packages (`yay -Syu` updates everything).

### Troubleshooting AUR Builds
If a large AUR package (like Brave or an IDE) finishes building but fails to install with a `sudo: timed out reading password` error, it means the compilation took longer than the default `sudo` timeout. 
- **Fix:** Simply rerun the install command (`yay -Syu`). The packages are already cached locally (`~/.cache/yay/`), so it will skip compilation and instantly prompt for the password to install.

---

## 9. Installed Applications & Development Environment

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

---

## 10. Desktop UI & Notifications (Waybar, Dunst, Screenshots)

### Waybar
- **Transparent Background:** The default opaque island background for Waybar was made fully transparent by setting `@define-color bar-bg rgba(0, 0, 0, 0.0);` in `~/.config/waybar/theme.css`.
- **Battery Accuracy:** Waybar's default polling could lag. Updated `~/.local/share/waybar/modules/battery.jsonc` to explicitly define `"bat": "BAT0"` and `"interval": 10` for reliable, snappy percentage updates.

### Dunst Notifications
- **Responsive Width & Padding:** By default, Dunst notifications were squishing text on long lines. Updated `~/.config/dunst/dunst.conf` to use a dynamic width (`width = (0, 300)` or `width = 300`) and shrunk icon sizes (`min_icon_size = 32`, `max_icon_size = 48`) to prioritize text readability. *(Note: Changes must be compiled using `hyde-shell wallbash dunst`)*.

### Screenshot Annotations (Swappy)
- **Direct to Clipboard:** By default, HyDE opens a screenshot annotation tool (Satty/Swappy) after capturing. This was disabled to allow instant "snip to clipboard" functionality.
- **Fix:** Added `[screenshot] annotation_enabled = false` to `~/.config/hyde/config.toml`.

### Hyprland Keybinding Conflicts
- **Super+Q & Super+W:** Custom keybindings in `~/.config/hypr/userprefs.conf` were overriding the default `keybindings.conf` behavior by mapping both to `killactive`. 
- **Fix:** Removed the custom overrides, restoring `Super+Q` to close the focused window, and `Super+W` to toggle floating mode.
