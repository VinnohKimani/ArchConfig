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

## Phase 8: Charger-Unplug Suspend Fix, Power Safety & Doc Audit
- **Battery regression (unplug = sleep)**: `battery-notify.sh` computed the level from `energy_now / energy_full_design` (~22% on this 33%-health pack) and contained a "critical battery" branch that called `systemctl suspend`, so every AC unplug suspended the laptop. Rewrote it as strictly notification-only, reading `BAT0/capacity` with a range guard.
- **Event storm removed**: `battery-monitor.sh` stopped trusting the lagging, flapping power-supply event/status stream and reads the physical `ADP1/online` pin instead, with `notify-send -r` de-duplication and a `flock` single instance. (Interim version: a 2 s poll with a 3 s settle; both were replaced later in this phase by the event-driven loop described below.)
- **Single suspend path**: `safe-suspend.sh` is now the only caller of `systemctl suspend` and fails safe (blocks on unreadable/unstable readings as well as on < 25% battery). `hypridle.conf` calls `~/.local/bin/safe-suspend.sh` instead of `systemctl suspend`.
- **Hyprland 0.56 banner** (`You are using the .conf config format...`): documented the Lua migration (`install.sh -r`, `lua`/`luarocks`, port `userprefs.conf` to `~/.config/hypr/hyprland.lua`, start via `hyde.lua`) plus the `IgnorePkg = hyprland` fallback to keep 0.57 from breaking the session mid-migration.
- **Stale notifier on the live system**: a second, older countdown notifier (“43% is critically low. Device will execute systemctl suspend in 1:56”) survived the change because only repository files were replaced. Added `battery-fix.sh`, which locates it by its marker strings, backs up and comments out its `systemctl suspend`/`loginctl suspend`/`pm-suspend` calls, stops the old daemon, installs the fixed trio, repoints `hypridle`, and restarts `battery-monitor.sh`. Root-owned copies are reported, never modified.
- **Realtime plug/unplug**: `battery-monitor.sh` is now event-driven — it blocks on the kernel `power_supply` uevent stream via `coproc`/`read -t` and falls back to a `0.25s` ADP1 check, removing the old 2 s poll and the 3 s settle (which guarded `BAT0/status` flapping, not the pin). Wake-from-sleep clock jumps re-sync silently instead of replaying a stale transition. `battery-notify.sh` retries a lagging `BAT0/capacity` four times and still fires without a percentage rather than dropping the event.
- **Realtime latency measured**: 80 ms (unplug) and 262 ms (plug) end-to-end on a fixture exercising the fallback tick; the uevent path on real hardware is expected to be faster still. Design, tuning knobs and troubleshooting recorded in `SYSTEM_CONFIGS.md` -> *Realtime Charger Plug/Unplug Notifications*.
- **Documentation audit**: fixed the `eduroam-jkuat/` file index (the repository never contained `eduroam-jkuat.nmconnection` or `test_eduroam.sh`), and corrected the Eduroam guide, which still described `iwd` as the active NetworkManager backend after the stack was reverted to `wpa_supplicant` in Phase 4.

## Phase 9: Battery Calibration, Touchpad Tuning & Hyprland Startup Banner Fix
- **Battery Low & Critical Suspend Calibration**:
  - Calibrated low battery notification threshold to **20%**: alerts the user to plug in charger (`Connect the charger` / `Please plug in charger now`).
  - Calibrated critical battery suspend threshold to **10%**: system only initiates suspend when battery drops to **10%** (with a grace-period countdown).
  - Fixed HyDE state configuration in `~/.local/state/hyde/staterc` (which previously set critical to 60% and low to 65%, triggering unwanted suspend countdowns at 39%).
  - Defined explicit configuration in `~/.config/hyde/config.toml` under `[battery.notify.threshold]` (`critical = 10`, `low = 20`).
  - Updated `~/.local/bin/battery-notify.sh` and repo scripts to sleep at <= 10% and notify at <= 20%.
  - Adjusted `MIN_SUSPEND_PERCENT` in `safe-suspend.sh` from 25% to 10% to align the safety guard with the new 10% threshold.
  - Fixed premature range checks in `~/.local/lib/hyde/batterynotify.sh` and restarted `hyde-Hyprland-battery-notify.service`.
- **Touchpad Acceleration & Gesture Calibration (`bcm5974`)**:
  - Enforced `natural_scroll = true` globally in `input` and specifically targeting the MacBook trackpad device (`bcm5974`) so two-finger scrolling direction 100% matches macOS natural scrolling.
  - Overrode HyDE's rigid `accel_profile = flat` with `accel_profile = adaptive` in `~/.config/hypr/userprefs.conf`. Restored natural macOS-like momentum, velocity scaling, and fine precision on the 2560x1600 Retina display.
  - Tuned pointer sensitivity to `0.2` to eliminate jittery overshooting.
  - Enabled `disable_while_typing = true` to prevent accidental palm clicks and cursor jumps while typing.
  - Enabled `middle_button_emulation = true` for easy middle-click pasting and link management.
- **Hyprland 0.56 Startup Banner Dismissal**:
  - Added `exec-once = sleep 2 && hyprctl dismissnotify` to `~/.config/hypr/userprefs.conf`. This cleanly dismisses the yellow `.conf` format deprecation banner on startup.

## Phase 10: Hyprland Stack Hold, ZRAM Thrashing Elimination, Script Sync & Banner Dismissal Fix
- **Hyprland Dependency Lock for System Updates**:
  - Diagnosed `pacman -Syu` dependency failure (`aquamarine` and `hyprgraphics` breaking library ABIs `libaquamarine.so=14-64` and `libhyprgraphics.so=4-64` when only `hyprland` was ignored).
  - Expanded `/etc/pacman.conf` to pin the entire interdependent Hyprland 0.56 stack together (`aquamarine hyprcursor hyprgraphics hypridle hyprland hyprland-guiutils hyprland-qt-support hyprlang hyprlock hyprpicker hyprpolkitagent hyprsunset hyprtoolkit hyprutils hyprwire xdg-desktop-portal-hyprland`).
  - Verified full dependency transaction resolution (`pacman -Syup` completes with 0 errors), allowing regular Arch system updates to proceed cleanly without breaking desktop compositor stability.
- **ZRAM Compression Thrashing & Memory Sluggishness Fix**:
  - Diagnosed extreme system freezing and CPU spikes (`kswapd0` / `zstd`) occurring when memory usage reached 7GB+: with `zram-size = ram` (8GB) and `vm.swappiness = 100`, physical RAM ran out of space to store compressed ZRAM pages, preventing swap-out while starving user applications.
  - Reconfigured `/etc/systemd/zram-generator.conf`: set `zram-size = ram / 2` (3.8GB) and switched compression from heavy `zstd` to low-latency `lz4`.
  - Configured `/etc/sysctl.d/99-vm.conf` with `vm.swappiness = 60` and `vm.page-cluster = 0` to prevent premature aggressive swapping and eliminate CPU thrashing loops.
- **Active Script Synchronization & Daemon Cleanup**:
  - Synced bug-fixed, event-driven scripts (`battery-monitor.sh`, `battery-notify.sh`, `safe-suspend.sh`) from `Arch-Configs/` to active runtime path `~/.local/bin/`.
  - Stopped and disabled redundant `battery-notify.timer` in systemd user units to prevent competing polling timers.
  - Active battery monitor daemon (`battery-monitor.sh`) now blocks on kernel `power_supply` uevents at 0% idle CPU overhead while preserving timely low-battery notifications.
- **Startup Deprecation Banner Dismissal Fix**:
  - Corrected invalid `hyprctl seterror disable` command to the native Hyprland notification dismissal API: `exec-once = sleep 2 && hyprctl dismissnotify` in `~/.config/hypr/userprefs.conf`.
- **Notification Size & Typography Calibration (Dunst)**:
  - Fixed enormous notification banners caused by `[Type-2]` app rule in Dunst applying `<span size="250%">` to all `HyDE Notify` messages (battery, charger, volume). Calibrated to a well-proportioned `<span font='14' weight='bold'>%s</span>\n%b`.
  - Tuned icon sizes to **48px–72px** and card width to **380px** with 14px padding.
  - Set body font to `JetBrainsMono Nerd Font 12` in `~/.config/hyde/config.toml`.
  - Fixed Dunst daemon dying after script reloads by using persistent HyDE service activation (`hyde-shell app -u hyde-notifications.service`) instead of unmanaged background subshells.
  - Updated both `~/.local/share/wallbash/scripts/dunst.sh` and repository `dunst.sh` so future theme and wallpaper changes maintain the compact sizing.
- **Keyboard Backlight Keys & Notification Labels**:
  - Installed `kbd_brightnesscontrol.sh` into `~/.local/lib/hyde/` and symlinked to `~/.local/bin/kbd_brightnesscontrol`, enabling the `XF86KbdBrightnessUp` and `XF86KbdBrightnessDown` keybinds in `userprefs.conf` to work.
  - Updated notification titles across all media controls:
    - Screen brightness: Labeled as **Screen Brightness** with percentage (`${brightness}%`) instead of raw device name `intel_backlight`.
    - Keyboard brightness: Labeled as **Keyboard Brightness** with percentage (`${brightness}%`) instead of generic text.
    - Volume: Labeled as **Volume**, **Volume Muted**, and **Microphone Muted** with clear percentage and output sink names.
- **Volume Key Auto-Unmute**:
  - Modified `change_volume()` in `volumecontrol.sh` to automatically disarm mute (`wpctl set-mute @DEFAULT_AUDIO_SINK@ 0` / `pamixer -u`) whenever Volume Up or Volume Down keys are pressed while the audio sink is muted.
  - Added [volumecontrol.sh](volumecontrol.sh) to repository tracking.

## Phase 11: Notification Stack Reforms & Critical Battery Timer Suspend (10%)
- **Critical Battery Auto-Suspend at 10% (1-Minute Grace Timer)**:
  - Configured `timer = 60` (1 minute / 60 seconds) in `~/.config/hyde/config.toml` (lowered from 120s) and updated `~/.local/state/hyde/config`.
  - Fixed silent execution failure in `~/.local/lib/hyde/batterynotify.sh`: `nohup "$execute_critical"` previously evaluated `"systemctl suspend"` as a literal executable name with space, failing with silent `command not found: systemctl suspend` and preventing the laptop from suspending. Replaced with `nohup bash -c "$execute_critical" &> /dev/null &`.
  - Polished notification typography & timer format: formatted remaining countdown time cleanly as `M:SS` (`1:00`, `0:59`...`0:01`) rather than raw `1:0`/`0:9`.
  - Added abort feedback: if the charger is plugged in during the 60-second countdown, notification ID 5 updates immediately to `"Charger Connected - Critical battery suspend cancelled."` instead of leaving stale warnings on screen.
- **Eliminated Duplicate Plug / Unplug Alerts**:
  - Resolved conflict between `battery-monitor.sh` (fast kernel uevents) and `batterynotify.sh` (DBus properties), which both fired notifications upon AC connect/disconnect.
  - Set `dock = true` in `~/.config/hyde/config.toml` to mute redundant status transitions in `batterynotify.sh`, leaving realtime charger alerts to `battery-monitor.sh` while preserving battery level thresholds (20% low warning, 10% critical suspend).
- **Notification Typography Consistency**:
  - Added `[Type-3]` rule for `appname = "HyDE Power"` in `dunst.sh`, `~/.local/share/wallbash/scripts/dunst.sh`, and `~/.config/dunst/dunstrc` to ensure battery notifications match the bold styling of other system dialogs.
- **Safe-Suspend Threshold Calibration**:
  - Lowered `MIN_SUSPEND_PERCENT` from 10% to 5% in `safe-suspend.sh` (and `~/.local/bin/safe-suspend.sh`) so closing the lid or idle timeout below 10% allows the machine to suspend safely to RAM rather than blocking suspend and dying while awake.
