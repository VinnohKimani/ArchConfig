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
| **Battery** | Internal Li-Poly (Degraded capacity) | UPower / ACPI | Safe-suspend wrapper (< 25% abort sleep) |
| **Compositor**| Hyprland (Wayland) | HyDE framework | Dynamic theming (Wallbash), Dunst, Waybar |

---

## 📂 Repository Architecture & File Index

```text
Arch-Configs/
├── README.md                  # Master repository documentation (this file)
├── SYSTEM_CONFIGS.md          # Comprehensive architectural reference & setup guide
├── CHANGELOG.md               # Chronological log of system changes & modifications (Phases 1-6)
├── PKGBUILD_maya              # Custom PKGBUILD for Autodesk Maya 2027 RPM extraction & install
├── config.jsonc               # Waybar / HyDE system status configuration
├── macos.jsonc                # macOS-inspired styling configuration for Waybar
├── user-style.css             # Custom desktop & panel CSS overrides
├── hypridle.conf              # Screen dim, lock screen, DPMS, and safe-suspend listeners
├── kbd_brightnesscontrol.sh   # SMC keyboard backlight increment/decrement helper script
├── dunst.sh                   # HyDE notification daemon theme generator & launcher
├── dunst.dcol                 # Dynamic Wallbash color palette template for Dunst
└── eduroam-jkuat/             # Enterprise WPA-EAP Wi-Fi suite for university access
    ├── README.md              # Eduroam setup, security model, and troubleshooting guide
    ├── eduroam-jkuat.nmconnection # Sanitized NetworkManager connection profile template
    ├── claude_diagnostics.sh  # Automated Wi-Fi diagnostic & certificate analyzer
    └── test_eduroam.sh        # Live connection testing and journal monitoring script
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
  1. Created `~/.local/bin/safe-suspend.sh` which checks AC power and battery level before sleeping. If battery is < 25% and unplugged, suspend is prevented and a critical warning notification is sent.
  2. Integrated safe-suspend into [hypridle.conf](hypridle.conf) (idle timeout) and `~/.config/hypr/userprefs.conf` (laptop lid switch).
  3. Calibrated UPower thresholds in `/etc/UPower/UPower.conf` (`PercentageCritical=5`, `PercentageAction=2`).

### 3. Trackpad Calibration & Wayland Browser Acceleration
- **Problem:** 
  1. Pinch-to-zoom in Brave Browser triggered full-page zoom steps (`Ctrl + +/-`), causing the entire webpage UI to expand awkwardly instead of zooming into the canvas.
  2. Interactive canvas sites (like Stitch, Figma, Maps) stuttered in "slow motion" due to stepped DOM re-layouts at 2560x1600 Retina resolution.
  3. Touchpad scrolling had an artificial 20% slowdown.
- **Resolution:**
  1. Created `~/.config/brave-flags.conf` with `--ozone-platform-hint=auto` and `--enable-features=TouchpadOzonePinch,TouchpadOverscrollHistoryNavigation` for 1:1 smooth hardware pinch zoom.
  2. Adjusted `scroll_factor = 1.0` in `~/.config/hypr/userprefs.conf`.

### 4. Autodesk Maya 2027 Integration
- **Problem:** Maya 2027 is built for enterprise RPM distributions (RHEL/CentOS). On Arch Linux, it failed to start due to library mismatches (`libjbig.so.2.1`), and Viewport 2.0 rendered black/frozen screens on Wayland/Mesa.
- **Resolution:**
  1. Custom [PKGBUILD_maya](PKGBUILD_maya) extracts RPM payloads, patches startup scripts, and links dependencies (`libxml2.so.2`, `xorg-fonts`).
  2. Symlinked `/usr/lib/libjbig.so.2.2` → `/usr/autodesk/maya2027/lib/libjbig.so.2.1` to resolve Arch's `jbigkit 2.2` soname bump.
  3. Configured `~/maya/2027/Maya.env` with `MAYA_VP2_DEVICE_OVERRIDE=VirtualDeviceGL` and `__GLX_VENDOR_LIBRARY_NAME=mesa` to force stable OpenGL Viewport rendering.
  4. Added `adsklicensing`, `webkit2gtk`, and `openssl-1.1` to `IgnorePkg` in `/etc/pacman.conf` to prevent `yay` from recompiling legacy C libraries on daily updates.

### 5. Storage Hygiene Protocol (92GB SSD)
- System storage is maintained through a strict budget:
  - Pacman cache pruned with `pacman -Sc` / `paccache -r`.
  - Systemd journals capped at 100MB with `journalctl --vacuum-size=100M`.
  - Staging builds in `~/Downloads/maya/pkg` and unneeded debug symbols (`*-debug`) pruned periodically.
  - Full protocol documented in [SYSTEM_CONFIGS.md](SYSTEM_CONFIGS.md).

---

## 📖 In-Depth Documentation Index

For complete step-by-step guides, configs, and architectural explanations:
* **[SYSTEM_CONFIGS.md](SYSTEM_CONFIGS.md)** — Exhaustive system guide covering package lists, battery fixes, sleep safety, terminal fonts, Maya installation, and storage maintenance.
* **[CHANGELOG.md](CHANGELOG.md)** — Detailed history of system modifications (Phases 1 through 6).
* **[eduroam-jkuat/README.md](eduroam-jkuat/README.md)** — Step-by-step enterprise Wi-Fi installation, certificate validation, and diagnostic tool documentation.
