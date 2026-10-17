# System Changes Log

## Phase 1: Safe Cleanup
- **Disabled `espeakup.service`**: Crashing on boot and unnecessary.
- **Disabled `NetworkManager-wait-online.service`**: Slowing down boot process unnecessarily.
- **Docker**: Switched to socket activation (`docker.service` disabled, `docker.socket` enabled) to save RAM and start Docker only on demand.
- **/boot Permissions**: User noted `fmask=0077,dmask=0077` applied to `/etc/fstab`, though live mount check indicated it might need a remount or correct reload.
- **mkinitcpio 'resume' Hook**: Left intact based on user instruction.

## Phase 2: Power
- **Power Daemons**: Diagnosed conflict between `auto-cpufreq` and `power-profiles-daemon`. Proposed disabling `auto-cpufreq`.
- **UPower**: Identified misconfiguration (`PercentageAction=27`) causing premature sudden shutdowns. Proposed UPower threshold fixes.

## Phase 3: Sleep
- **Safe Suspend Wrapper**: Created `~/.local/bin/safe-suspend.sh` to intercept sleep requests and abort them if battery is below 25% and unplugged, preventing "dead on wake" scenarios.
- **Config Updates**: Hooked the safe-suspend script into `~/.config/hypr/hypridle.conf` (idle timeout) and `~/.config/hypr/userprefs.conf` (lid switch).

## Phase 4: Wi-Fi Stack
- **Backend Switch**: Removed `iwd` overrides from `/etc/NetworkManager/conf.d/` and disabled `iwd.service` due to DHCP conflicts. Switched NetworkManager back to the native `wpa_supplicant` backend. Unmasked and enabled `wpa_supplicant.service`.
- **Eduroam**: Prepared the existing `eduroam` NetworkManager profile for WPA-EAP PEAP/MSCHAPv2 authentication.

## Phase 5: Storage Optimization & Maintenance Protocols
- **Pacman Syntax Fix**: Corrected `/etc/pacman.conf` where `IgnorePkg` was misplaced under `[multilib]` instead of `[options]`, resolving syntax errors on package updates.
- **Journal Vacuuming**: Vacuumed archived systemd logs down to 100MB (`journalctl --vacuum-size=100M`), reclaiming ~1GB of root storage.
- **Cache Cleans**: Removed stale package caches (`pacman -Sc`), AUR build caches (`~/.cache/yay`), runtime package caches (`~/.cache/.bun`, `~/.cache/uv`), and redundant configuration backup snapshots (`~/backup-audit`), freeing over 9GB of disk space.

## Phase 6: Trackpad & Wayland Browser Acceleration (Brave & Hyprland)
- **Brave Wayland Flags**: Created `~/.config/brave-flags.conf` with native Wayland Ozone platform, `TouchpadOzonePinch`, and GPU rasterization flags. This resolved browser page layout blowups (entire page expanding/zooming on pinch) and fixed slow-motion canvas stuttering on high-resolution Retina displays.
- **Touchpad Calibration**: Adjusted `scroll_factor = 1.0` in `~/.config/hypr/userprefs.conf` to remove artificial scrolling slowdown while retaining natural scrolling and tap-to-click.

## Phase 7: Power Button Protection, Sleep/Wake Latency Fixes & Storage Expansion Protocol
- **Power Button Accidental Shutdown Protection**: Configured `/etc/systemd/logind.conf.d/ignore-power-key.conf` with `HandlePowerKey=ignore` and `HandlePowerKeyLongPress=ignore`. This ensures that accidental taps or brief holds of the power button will never shut down the system. Emergency SMC hardware cutoff (holding physical button for 7–10s) remains intact at the motherboard level.
- **Sleep & Resume Latency Fixes**:
  - **Internal Keyboard/Trackpad Wake (`SPIT`)**: Diagnosed `/proc/acpi/wakeup` where `SPIT` (Apple SPI bus `spi-APP000D:00`) was disabled, preventing built-in keys and trackpad clicks from waking the laptop. Created and enabled `/etc/systemd/system/macbook-wakeup.service` to automatically enable `SPIT` on boot.
  - **Broadcom Bluetooth Sleep Timeout (Error -110)**: Identified Broadcom Bluetooth (`05ac:8290` / `btusb`) failing suspend with `error -110` (ETIMEDOUT) and stalling system resume for 15+ seconds. Created `/etc/modprobe.d/btusb.conf` with `options btusb enable_autosuspend=n` to eliminate the autosuspend timeout loop.
- **Dual-Boot Storage Expansion Protocol (Option A)**:
  - Formulated and documented Option A to expand storage on the dual-boot system with macOS Sequoia. Shrinking the APFS container (`sda2`) from macOS creates unallocated space before Arch Linux (`sda3`), which can be safely partitioned as `/dev/sda4` and mounted for extra storage without risking the root filesystem.

