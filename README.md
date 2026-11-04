# 🍎 Arch-Configs: MacBook Pro 2015 (Retina) System Suite

A complete, production-grade configuration suite, hardware workarounds, and stabilization scripts for **Arch Linux** running on an **Apple MacBook Pro 13-inch (Early 2015 - MacBookPro12,1)** with **Hyprland** (HyDE framework).

---

## 💻 Hardware Profile & Specifications

| Component | Hardware Specification | Driver / Subsystem | Key Configuration |
| :--- | :--- | :--- | :--- |
| **Model** | MacBook Pro 13" (Early 2015, Retina) | Apple ACPI / SMC | `MacBookPro12,1` |
| **Processor** | Intel Core i5-5257U @ 2.70GHz | Broadwell microcode | `intel-ucode`, `power-profiles-daemon` |
| **Graphics** | Intel Iris Graphics 6100 (GT3) | Mesa `crocus` / OpenGL 4.5 | Wayland native, 2560x1600 @ 1.6 scale |
| **Display** | 13.3" IPS Retina Display (2560x1600) | Wayland / DRM | Fractional scaling 1.6 in `monitors.conf` |
| **Trackpad** | Broadcom BCM5974 Multitouch | `bcm5974` / libinput | `scroll_factor = 1.0`, natural scroll |
| **Keyboard** | Apple Internal Keyboard & Backlight | `apple` HID / SMC | Custom brightness via `kbd_brightnesscontrol.sh` |
| **Wi-Fi / BT** | Broadcom BCM43602 (802.11ac) | `brcmfmac` / `wpa_supplicant` | `feature_disable=0x82000`, MAC rand off |
| **Battery** | Internal Li-Poly (Degraded capacity) | UPower / ACPI | Calibrated monitor (20% plug-in, 10% suspend guard) |
| **Compositor**| Hyprland (Wayland) | HyDE framework | Dynamic theming (Wallbash), Dunst, Waybar |

---

## 📂 Repository Architecture & File Index

```text
Arch-Configs/
├── README.md                  # Master repository documentation (this file)
├── SYSTEM_CONFIGS.md          # Comprehensive architectural reference & setup guide
├── CHANGELOG.md               # Chronological log of system changes & modifications (Phases 1-9)
├── config.jsonc               # Waybar / HyDE system status configuration
├── macos.jsonc                # macOS-inspired styling configuration for Waybar
├── user-style.css             # Custom desktop & panel CSS overrides
├── hypridle.conf              # Screen dim, lock screen, DPMS, and safe-suspend listeners
├── kbd_brightnesscontrol.sh   # SMC keyboard backlight increment/decrement helper script
├── battery-monitor.sh         # Event-driven ADP1 watcher, 250ms fallback (notify only, never suspends)
├── battery-notify.sh          # Charger/battery notification script (notify only)
├── safe-suspend.sh            # Guarded suspend wrapper, the only path to S3
├── battery-fix.sh             # Finds/disarms the old countdown notifier and installs the trio
├── dunst.sh                   # HyDE notification daemon theme generator & launcher
├── dunst.dcol                 # Dynamic Wallbash color palette template for Dunst
└── eduroam-jkuat/             # Enterprise WPA-EAP Wi-Fi suite for university access
    ├── README.md              # Eduroam setup, security model, and troubleshooting guide
    ├── eduroam.8021x          # WPA-EAP PEAP/MSCHAPv2 profile template (credentials redacted)
    ├── jkuat_ca.pem           # JKUAT RADIUS CA certificate
    ├── install_eduroam.sh     # Installs the profile with root-only permissions
    ├── claude_diagnostics.sh  # Automated Wi-Fi diagnostic & certificate analyzer
    └── claude_diagnostics_2.sh # Second-pass diagnostic (association + DHCP testing)
```

---

## 🛠️ Key Subsystems & Hardware Workarounds

### 1. Wi-Fi Connectivity & Eduroam Enterprise (Broadcom BCM43602)
- **Problem:** The built-in Broadcom BCM43602 Wi-Fi chip repeatedly failed to associate with modern WPA2/WPA3 access points, causing 90-second timeout loops and `NO-CARRIER` states.
- **Root Cause:** Firmware bugs in hardware offloading/roaming, combined with NetworkManager MAC randomization and `iwd` DHCP backend incompatibilities.
- **Resolution:**
  1. Set kernel module option `options brcmfmac feature_disable=0x82000` in `/etc/modprobe.d/brcmfmac.conf`.
  2. Disable MAC randomization in `/etc/NetworkManager/conf.d/mac-rand.conf`.
  3. Revert NetworkManager backend to stable `wpa_supplicant` (`iwd` removed).
  4. Full university enterprise setup documented in [eduroam-jkuat/README.md](eduroam-jkuat/README.md).

### 2. Power Management & Safe Suspend Wrapper
- **Problem:** When unplugged, waking from sleep or sleeping below ~25% battery caused sudden power loss and hard shutdowns ("dead on wake").
- **Root Cause:** Hardware battery degradation coupled with aggressive UPower critical action thresholds (`PercentageAction=27`).
- **Resolution:**
  1. [safe-suspend.sh](safe-suspend.sh) checks AC power and battery level before sleeping. If the battery is < 10% and unplugged, suspend is prevented and a critical warning notification is sent. It fails safe: an unreadable or unstable reading also blocks the suspend.
  2. Integrated into [hypridle.conf](hypridle.conf) (idle timeout) and `~/.config/hypr/userprefs.conf` (laptop lid switch). It is the **only** path to S3 — no config calls `systemctl suspend` directly.
  3. Calibrated UPower thresholds in `/etc/UPower/UPower.conf` (`PercentageCritical=5`, `PercentageAction=2`).
  4. **Regression fixed (Oct 2026):** removing the charger used to put the laptop to sleep. The notification script derived the level from `energy_now / energy_full_design` (~22% on a 33% health battery) and its "critical battery" branch suspended the machine on every unplug. Now [battery-notify.sh](battery-notify.sh) reads `BAT0/capacity`, is strictly notify-only, and [battery-monitor.sh](battery-monitor.sh) is event-driven: it wakes on kernel `power_supply` uevents with a 250ms `ADP1/online` fallback tick, so plug/unplug notifications land instantly (measured 80 ms unplug / 262 ms plug on the fallback path). Design, latency budget, tuning knobs and troubleshooting in [SYSTEM_CONFIGS.md](SYSTEM_CONFIGS.md#realtime-charger-plugunplug-notifications).
  5. **Cleaning up an existing machine:** a second, older notifier can still be installed and running — its popup reads "43% is critically low. Device will execute systemctl suspend in 1:56". Run `./battery-fix.sh --dry-run` to see whether it is present, then `./battery-fix.sh` to disarm it and install the fixed trio. See [SYSTEM_CONFIGS.md](SYSTEM_CONFIGS.md#a-second-notifier-can-survive-the-fix-the-countdown-banner).

### 3. Trackpad Calibration & Wayland Browser Acceleration
- **Problem:** 
  1. Pinch-to-zoom in Brave Browser triggered full-page zoom steps (`Ctrl + +/-`), causing the entire webpage UI to expand awkwardly instead of zooming into the canvas.
  2. Interactive canvas sites (like Stitch, Figma, Maps) stuttered in "slow motion" due to stepped DOM re-layouts at 2560x1600 Retina resolution.
  3. Touchpad scrolling had an artificial 20% slowdown.
- **Resolution:**
  1. Created `~/.config/brave-flags.conf` with `--ozone-platform-hint=auto` and `--enable-features=TouchpadOzonePinch,TouchpadOverscrollHistoryNavigation` for 1:1 smooth hardware pinch zoom.
  2. In `~/.config/hypr/userprefs.conf`, overrode HyDE's `accel_profile = flat` with `accel_profile = adaptive` and tuned `sensitivity = 0.2` with `disable_while_typing = true` and `middle_button_emulation = true` for natural momentum and palm rejection.
  3. Adjusted `scroll_factor = 1.0` in `~/.config/hypr/userprefs.conf`.

### 4. Storage Hygiene & Dual-Boot Expansion Protocol
- System storage is maintained through a strict budget:
  - Pacman cache pruned with `pacman -Sc` / `paccache -r`.
  - Systemd journals capped at 100MB with `journalctl --vacuum-size=100M`.
  - Unneeded debug symbols (`*-debug`) pruned periodically.
- **Dual-Boot Expansion (Option A):** Documented the safest path to reclaim storage from macOS Sequoia. Shrinking the APFS container in macOS creates free space before the Arch partition, which is formatted as `/dev/sda4` and mounted as extra data storage without modifying existing root filesystem sectors.
  - Full protocol documented in [SYSTEM_CONFIGS.md](SYSTEM_CONFIGS.md).

### 5. Hyprland 0.56 Desktop Stability & System Updates
- **Problem:** Startup banner (*"You are using the .conf config format, support for which will be removed in Hyprland 0.57"*) and update dependency conflicts (`pacman -Syu` breaking on `aquamarine`/`hyprgraphics` ABIs when only `hyprland` was ignored).
- **Resolution:**
  1. Pin the entire interdependent Hyprland 0.56 stack (`IgnorePkg = aquamarine hyprcursor hyprgraphics hypridle hyprland hyprland-guiutils hyprland-qt-support hyprlang hyprlock hyprpicker hyprpolkitagent hyprsunset hyprtoolkit hyprutils hyprwire xdg-desktop-portal-hyprland`) in `/etc/pacman.conf`. This allows all system updates to run cleanly while keeping the HyDE `.conf` desktop completely stable.
  2. Auto-dismiss the deprecation warning on startup via `exec-once = sleep 2 && hyprctl dismissnotify` in `~/.config/hypr/userprefs.conf`.
  3. When HyDE upstream finalizes its stable automated Lua dotfile installer, migrate configs to Lua and unpin the stack. Detailed procedure in [SYSTEM_CONFIGS.md](SYSTEM_CONFIGS.md).

### 6. Memory Thrashing & Freezing Fix (ZRAM + Swap)
- **Problem:** Extreme sluggishness and CPU lockups at 7GB+ RAM usage caused by ZRAM thrashing (8GB ZRAM starved physical RAM, preventing swapping).
- **Resolution:** Sized ZRAM to 50% physical RAM (`zram-size = ram / 2`, ~3.8GB) with lightweight `lz4` compression in `/etc/systemd/zram-generator.conf`, set `vm.swappiness = 60` and `vm.page-cluster = 0` in `/etc/sysctl.d/99-vm.conf`, and preserved the 8GB `/swapfile` as deep overflow protection.

### 7. Power Button Protection & Sleep/Wake Optimization
- **Power Button:** Configured `/etc/systemd/logind.conf.d/ignore-power-key.conf` (`HandlePowerKey=ignore`) to protect against accidental shutdowns from keyboard brush hits.
- **Sleep/Wake Latency:** Enabled SPI ACPI wakeup (`SPIT`) via `macbook-wakeup.service` for instant keyboard/trackpad wake, and disabled Bluetooth autosuspend (`btusb.enable_autosuspend=n`) to eliminate 15-second resume hangs (error -110).

---

## 📖 In-Depth Documentation Index

For complete step-by-step guides, configs, and architectural explanations:
* **[SYSTEM_CONFIGS.md](SYSTEM_CONFIGS.md)** — Exhaustive system guide covering package lists, battery fixes, sleep safety, terminal fonts, power button protections, and storage maintenance.
* **[CHANGELOG.md](CHANGELOG.md)** — Detailed history of system modifications (Phases 1 through 10).
* **[eduroam-jkuat/README.md](eduroam-jkuat/README.md)** — Step-by-step enterprise Wi-Fi installation, certificate validation, and diagnostic tool documentation.
