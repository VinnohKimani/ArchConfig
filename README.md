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
| **Battery** | Internal Li-Poly (Degraded capacity) | UPower / ACPI | Calibrated monitor (20% low warning, 10% 1-min suspend timer) |
| **Compositor**| Hyprland 0.57.2 (Wayland) | HyDE Lua framework | Native Lua API (`hyprland.lua`), macOS animations, Dunst, Waybar |
| **Audio Subsystem**| Cirrus Logic CS4208 Dual Array | PipeWire / HDA Intel | Internal woofers active (`Pin 0x13`), 9-stage DSP anti-clipping filter |
| **Memory / Swap**| 8GB DDR3L + Tiered Swap | zram-generator / fstab | 7.7GB ZRAM (`lz4`, prio 100) + 8GB SSD swapfile (prio 10) + `swappiness=150` |

---

## 📂 Repository Architecture & File Index

```text
Arch-Configs/
├── README.md                  # Master repository documentation (this file)
├── SYSTEM_CONFIGS.md          # Comprehensive architectural reference & setup guide
├── CHANGELOG.md               # Chronological log of system changes & modifications (Phases 1-16)
├── config.jsonc               # Waybar / HyDE system status configuration
├── macos.jsonc                # macOS-inspired styling configuration for Waybar
├── user-style.css             # Custom desktop & panel CSS overrides
├── monitors.conf              # Multi-monitor & HiDPI configuration (integer scale 1 for external displays)
├── hyprland.lua               # Hyprland 0.57+ (HyDE Lua) user overrides, keybindings, monitor & touchpad config
├── display-switch.sh          # Quick projector/display mode switcher (Super + P: Mirror, Extend, Single)
├── hypridle.conf              # Screen dim, lock screen, DPMS, and safe-suspend listeners
├── zram-generator.conf        # Tier-1 ZRAM swap config (lz4, ram / 2, priority 100)
├── 99-vm.conf                 # Kernel VM & 8GB RAM watermark/cache sysctl tuning
├── 99-macbook-pro-2015-dsp.conf # Native PipeWire 9-stage anti-clipping EQ & speaker DSP for CS4208
├── cs4208-mbp121.fw           # HDA firmware patch enabling CS4208 Bass Woofers (Pin 0x13 / DAC 0x04)
├── alsa-macbook.conf          # snd_hda_intel modprobe config loading cs4208-mbp121.fw
├── enable-cs4208-woofers.py   # Live HDA verb enabler for CS4208 dual-speaker/woofer array
├── MacBook-Pro-2015-Speakers.json # EasyEffects speaker mastering preset (Bass Enhancer + 10-band EQ + Limiter)
├── screenshot.sh              # Direct-to-clipboard & ~/Pictures/Screenshots capture (no preview popup)
├── brightnesscontrol.sh       # Screen backlight (intel_backlight) +/- helper with Dunst progress notification
├── kbd_brightnesscontrol.sh   # SMC keyboard backlight increment/decrement helper script
├── battery-monitor.sh         # Event-driven ADP1 watcher, 250ms fallback (notify only, never suspends)
├── battery-notify.sh          # Charger/battery notification script (notify only)
├── safe-suspend.sh            # Guarded suspend wrapper, the only path to S3
├── battery-fix.sh             # Finds/disarms the old countdown notifier and installs the trio
├── dunst.sh                   # HyDE notification daemon theme generator & launcher
├── dunst.dcol                 # Dynamic Wallbash color palette template for Dunst
├── macbook-wakeup.service     # Systemd unit enabling Apple SPI keyboard/trackpad ACPI wake (SPIT)
├── btusb.conf                 # Modprobe config disabling Bluetooth autosuspend (fixes 15s wake hang)
├── brcmfmac.conf              # Modprobe config disabling buggy Broadcom Wi-Fi offload (fixes 5GHz drops)
├── mac-rand.conf              # NetworkManager config disabling scan MAC randomization
├── ignore-power-key.conf      # systemd-logind config protecting against accidental power-key hits
├── hyprlock.sh                # HyDE hyprlock manager script with layout switcher fix
├── hyprlock.pam               # System PAM configuration for hyprlock using system-auth
├── hyprlock/                  # Custom hyprlock layouts
│   ├── macOS Sonoma.conf      # Apple glassmorphism layout with thin clock, avatar & battery
│   ├── Minimalist Clock.conf  # High-contrast bold stacked time with Wallbash accents
│   └── Cyberpunk HUD.conf     # Monospace sci-fi terminal layout with neon glowing border
├── apply-system-fixes.sh      # Automated root installer for ZRAM, swapfile, sysctl & woofers
├── apply-hardware-tweaks.sh   # Automated root installer for SPI wake, Bluetooth, Wi-Fi & power key
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
  1. [safe-suspend.sh](safe-suspend.sh) checks AC power and battery level before sleeping. If the battery is < 5% and unplugged, suspend is prevented to avoid inrush voltage sag on resume.
  2. Integrated into [hypridle.conf](hypridle.conf) (idle timeout) and `~/.config/hypr/userprefs.conf` (laptop lid switch).
  3. **Critical Battery Auto-Suspend (10% with 1-Minute Timer):** When on battery and capacity drops to 10%, an active 60-second countdown notification begins. If the charger is plugged in during the countdown, the action is cancelled immediately with a confirmation notification. If 60 seconds elapse without plugging in, the system initiates `systemctl suspend` to sleep safely in RAM before the laptop runs out of power and dies.
  4. **Deduplicated Notifications:** Configured `dock = true` in `~/.config/hyde/config.toml` so `batterynotify.sh` delegates charger plug/unplug events to [battery-monitor.sh](battery-monitor.sh) (80 ms uevent detection) while managing capacity thresholds (20% low warning, 10% auto-suspend).
  5. Calibrated UPower thresholds in `/etc/UPower/UPower.conf` (`PercentageCritical=5`, `PercentageAction=2`).
  6. **Regression fixed:** [battery-notify.sh](battery-notify.sh) reads `BAT0/capacity` directly, is strictly notify-only, and [battery-monitor.sh](battery-monitor.sh) is event-driven on kernel `power_supply` uevents with a 250ms fallback tick. Design and tuning details in [SYSTEM_CONFIGS.md](SYSTEM_CONFIGS.md#realtime-charger-plugunplug-notifications).

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
- **Dual-Boot Expansion (100GB $\rightarrow$ 220GB):** Reclaimed `120GB` from the macOS Monterey APFS container (`disk0s2` shrunk from `399.6GB` to `280.0GB`). Documented both **Method B (Unified `220GB` `/` Root Partition via Live USB `sfdisk --move-data` + `resize2fs`)** and **Method A (Dedicated `/dev/sda4` Secondary Partition)**.
  - Full protocol documented in [SYSTEM_CONFIGS.md](SYSTEM_CONFIGS.md).

### 5. Hyprland 0.57+ Native Lua Desktop Architecture
- **Evolution:** Hyprland 0.57 completely removed support for legacy `.conf` user configurations in favor of a native, programmable Lua configuration API.
- **Active Setup:** 
  1. Operating natively on Hyprland `0.57.2-1` using `hyprland.lua` (and version-controlled in [hyprland.lua](hyprland.lua)).
  2. All package pinning (`IgnorePkg`) in `/etc/pacman.conf` has been unpinned; updates resolve cleanly.
  3. Integrated MacBook Pro Retina scaling (`scale = 1.6` on `eDP-1`, integer `1.0` on external displays).
  4. Broadcom BCM5974 trackpad tuned with `tap_and_drag = false`, `drag_lock = false`, `natural_scroll = true`, and `accel_profile = "adaptive"` to eliminate tab tearing and pointer clumsiness.

### 6. Tiered Memory Architecture (7.7GB ZRAM + 8GB SSD Swapfile + Anti-Stutter VM Sysctl)
- **Problem:** Sluggishness, thrashing, and high I/O wait times under heavy load caused by low swappiness (60) purging executable app code and 1.5GB dirty page accumulation stalls.
- **Resolution:** Calibrated an optimized 15.7 GiB memory hierarchy:
  1. **Tier-1 ZRAM (`/dev/zram0`, 7.7 GiB, Priority 100):** Full physical RAM size pool using ultra-fast `lz4` compression in `/etc/systemd/zram-generator.conf` decompresses at >3,000 MB/s, absorbing 7–8 GB of data in ~2.5–3.0 GB RAM.
  2. **Tier-2 SSD Swapfile (`/swapfile`, 8.0 GiB, Priority 10):** Safe deep overflow cushion on the SSD to absorb cold background pages.
  3. **VM Watermark & Anti-Stutter Tuning (`/etc/sysctl.d/99-vm.conf`):** `vm.swappiness = 150` (prioritizes compressing idle anonymous memory into ZRAM over dropping executable app code), `vm.dirty_ratio = 10` & `vm.dirty_background_ratio = 5` (stops 1.5GB synchronous disk write freezes), `vm.vfs_cache_pressure = 100` (balanced metadata reclaim), and `vm.watermark_scale_factor = 125` (proactive kswapd wake).
  4. **Active OOM Guardian:** `systemd-oomd.service` enabled to prevent hard system freezes.

### 7. Power Button Protection & Sleep/Wake Latency (Applied & Active)
- **Power Button Protection:** Configured `/etc/systemd/logind.conf.d/ignore-power-key.conf` (`HandlePowerKey=ignore`, `HandlePowerKeyLongPress=ignore`) to guard against accidental shutdowns from brushing the power button next to Delete.
- **Sleep/Wake Latency:** Enabled SPI ACPI wakeup (`SPIT`) via `macbook-wakeup.service` for instant keyboard/trackpad wake, and disabled Bluetooth autosuspend (`btusb.enable_autosuspend=n` in `/etc/modprobe.d/btusb.conf`) to eliminate the 15-second resume delay (error -110).
- **Wi-Fi Stability & Scan Optimization:** Configured `/etc/modprobe.d/brcmfmac.conf` (`feature_disable=0x82000`) and `/etc/NetworkManager/conf.d/mac-rand.conf` (`wifi.scan-rand-mac-address=no`) to eliminate 5GHz packet drops and driver crashes.
- **Automated Installer:** All 5 tweaks are packaged in [apply-hardware-tweaks.sh](apply-hardware-tweaks.sh).

### 8. External Displays, Projectors & HDMI Hotplugging
- **Problem:** Connecting external displays or projectors resulted in KMS DRM page-flip errors (`Cannot commit when a page-flip is awaiting`) and blank outputs on Intel Iris 6100.
- **Resolution:**
  1. Enforced strict integer scaling (`scale = 1`) for all external outputs (`HDMI-A-1`, `HDMI-A-2`, `DP-1`, `DP-2`) in `monitors.conf`, avoiding driver crash loops caused by fractional scaling on legacy Intel DRM.
  2. Created [display-switch.sh](display-switch.sh) bound to **`Super + P`** (**`Cmd + P`**) with a quick Rofi menu for **Mirror**, **Extend**, **Laptop Only**, **External Only**, and GUI settings (`nwg-displays`).

### 9. Rofi HiDPI Layout Engine & Quad Theming
- **Problem:** Pressing `Cmd + Shift + T` (Theme Select) or `Cmd + Shift + W` (Wallpaper Select) opened an empty dark rectangle due to a fractional scaling math error (`sed "s/\.//"` multiplied 1.6 scale to 16, resulting in a false 16,000px display width and 38 columns that collapsed Rofi's element engine).
- **Resolution:**
  1. Fixed logical resolution calculation via `awk` floating-point division and clamped columns between 2 and 4.
  2. Restored Arch HyDE's canonical **Quad Style (Style 2)** theme selector with floating cards over a transparent background (`#00000003`), 4-way preview collage on the left (`.quad`), centered titles on the right, and clean selection highlighting without thick surrounding bezels.

### 10. Instant Snip-to-Clipboard & Image Thumbnail Notification
- **Problem:** Capturing screenshots previously opened a large Satty/Swappy preview window obstructing the screen and requiring extra clicks to close.
- **Resolution:**
  1. Enforced `SCREENSHOT_ANNOTATION_ENABLED=false` in [screenshot.sh](screenshot.sh) and `[screenshot] annotation_enabled = false` in `~/.config/hyde/config.toml`.
  2. Pressing **`Cmd + Shift + S`** (`Super + Shift + S`) immediately copies the selected area to the Wayland clipboard, auto-saves to `~/Pictures/Screenshots/`, and generates a clean Dunst notification displaying the captured screenshot as an image thumbnail icon.

### 11. Cirrus CS4208 Dual-Speaker & Woofer Activation (Audio Hardware Fix)
- **Problem:** Internal speakers sounded thin and tinny because the kernel audio driver only routed audio to the upper tweeters (`Pin 0x12` / `DAC 0x03`), leaving the bass woofers (`Pin 0x13` / `DAC 0x04`) asleep in power state `D3` and muted.
- **Resolution:**
  1. Created [enable-cs4208-woofers.py](enable-cs4208-woofers.py) and persistent unit `macbook-cs4208-woofers.service` to wake DAC 0x04, unmute woofers to 0dB, enable GPIO speaker amplifiers, and mirror stereo audio.
  2. Installed [99-macbook-pro-2015-dsp.conf](99-macbook-pro-2015-dsp.conf) PipeWire filter chain providing -4.0dB anti-clipping digital headroom, 55Hz sub-bass highpass, +4dB bass resonance, and chassis resonance notch cuts.

### 12. macOS Fluidity & UI Polish
- **Smooth Workspace Transitions:** Configured `macSmooth` cubic bezier (`0.25, 0.1, 0.25, 1.0`) with `slidefade 20%` speed `6.0` on `workspaces`, `workspacesIn`, and `workspacesOut` for fluid, horizontal Spaces-like switching.
- **App Animations:** Windows open with physical popin spring curves (`spring:macOpen`) and close smoothly (`spring:macBounce`).
- **Rofi Bezel Margin:** Adjusted `get_rofi_pos()` in `~/.local/lib/hyde/pyutils/compositor.py` to prevent menus from clinging to the screen edge.
- **Instant Terminal Startup:** Disabled auto-running fastfetch in `~/.config/zsh/user.zsh`.

---

## 📖 In-Depth Documentation Index

For complete step-by-step guides, configs, and architectural explanations:
* **[SYSTEM_CONFIGS.md](SYSTEM_CONFIGS.md)** — Exhaustive system guide covering package lists, battery fixes, sleep safety, terminal fonts, power button protections, display scaling, screenshot persistence, and storage maintenance.
* **[CHANGELOG.md](CHANGELOG.md)** — Detailed history of system modifications (Phases 1 through 16).
* **[eduroam-jkuat/README.md](eduroam-jkuat/README.md)** — Step-by-step enterprise Wi-Fi installation, certificate validation, and diagnostic tool documentation.
