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
