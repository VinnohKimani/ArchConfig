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
## Phase 8: Autodesk Maya Decommissioning & Massive Storage Recovery
- **Package & Dependency Purge**: Uninstalled `maya 2027.2-1`, `adsklicensing`, `adskidentitymanager`, `adp-desktop-sdk`, `libtiff5`, `openssl-1.1`, `webkit2gtk`, and legacy `libsoup` using `pacman -Rns`. Removed orphaned build helper `chrpath`.
- **System Cleanup & Configuration Reversion**:
  - Cleaned `/etc/pacman.conf` by resetting `#IgnorePkg =` to defaults.
  - Removed passwordless sudo rule `/etc/sudoers.d/adsklicensing`.
  - Removed floating window rules for Maya and Autodesk Identity Manager from `~/.config/hypr/windowrules.conf`.
  - Removed Autodesk MIME scheme handlers from `~/.config/mimeapps.list`.
  - Removed legacy symlink `/usr/lib/libjbig.so.2.1`.
- **Storage Reclaim (+22.2 GB)**: Deleted 14GB of RPMs and staging builds in `~/Downloads/maya`, unpacked resources in `~/Downloads/SetupRes` and `~/Downloads/manifest`, all user preferences and environments in `~/maya`, and application roots in `/usr/autodesk` and `/opt/Autodesk`. Dropped root disk usage from 89% (9.8GB free) to 64% (32GB free).

## Phase 9: Charger-Unplug Suspend Fix, Hyprland 0.56 Lua Migration & Doc Audit
- **Battery regression (unplug = sleep)**: `battery-notify.sh` computed the level from `energy_now / energy_full_design` (~22% on this 33%-health pack) and contained a "critical battery" branch that called `systemctl suspend`, so every AC unplug suspended the laptop. Rewrote it as strictly notification-only, reading `BAT0/capacity` with a range guard.
- **Event storm removed**: `battery-monitor.sh` stopped trusting the lagging, flapping power-supply event/status stream and reads the physical `ADP1/online` pin instead, with `notify-send -r` de-duplication and a `flock` single instance. (Interim version: a 2 s poll with a 3 s settle; both were replaced later in this phase by the event-driven loop described below.)
- **Single suspend path**: `safe-suspend.sh` is now the only caller of `systemctl suspend` and fails safe (blocks on unreadable/unstable readings as well as on < 25% battery). `hypridle.conf` calls `~/.local/bin/safe-suspend.sh` instead of `systemctl suspend`.
- **Hyprland 0.56 banner** (`You are using the .conf config format...`): documented the Lua migration (`install.sh -r`, `lua`/`luarocks`, port `userprefs.conf` to `~/.config/hypr/hyprland.lua`, start via `hyde.lua`) plus the `IgnorePkg = hyprland` fallback to keep 0.57 from breaking the session mid-migration.
- **Stale notifier on the live system**: a second, older countdown notifier (“43% is critically low. Device will execute systemctl suspend in 1:56”) survived the change because only repository files were replaced. Added `battery-fix.sh`, which locates it by its marker strings, backs up and comments out its `systemctl suspend`/`loginctl suspend`/`pm-suspend` calls, stops the old daemon, installs the fixed trio, repoints `hypridle`, and restarts `battery-monitor.sh`. Root-owned copies are reported, never modified.
- **Realtime plug/unplug**: `battery-monitor.sh` is now event-driven — it blocks on the kernel `power_supply` uevent stream via `coproc`/`read -t` and falls back to a `0.25s` ADP1 check, removing the old 2 s poll and the 3 s settle (which guarded `BAT0/status` flapping, not the pin). Wake-from-sleep clock jumps re-sync silently instead of replaying a stale transition. `battery-notify.sh` retries a lagging `BAT0/capacity` four times and still fires without a percentage rather than dropping the event.
- **Realtime latency measured**: 80 ms (unplug) and 262 ms (plug) end-to-end on a fixture exercising the fallback tick; the uevent path on real hardware is expected to be faster still. Design, tuning knobs and troubleshooting recorded in `SYSTEM_CONFIGS.md` -> *Realtime Charger Plug/Unplug Notifications*.
- **Documentation audit**: fixed the `eduroam-jkuat/` file index (the repository never contained `eduroam-jkuat.nmconnection` or `test_eduroam.sh`), and corrected the Eduroam guide, which still described `iwd` as the active NetworkManager backend after the stack was reverted to `wpa_supplicant` in Phase 4.
