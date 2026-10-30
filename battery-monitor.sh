#!/usr/bin/env bash
# battery-monitor.sh — watches the AC adapter pin and calls battery-notify.sh on
# every real plug/unplug transition. Started from the Hyprland session
# (~/.config/hypr/userprefs.conf or the Lua equivalent), not from a system unit.
#
# This daemon never suspends, locks or blanks anything. Its only side effect is
# a notification.
#
# Why polling ADP1/online instead of `udevadm monitor -s power_supply`:
# on the MacBookPro12,1 the udev power_supply event is emitted with the same
# 10-15s SMC lag as BAT0/status, and the udev stream replays every quirk of the
# degraded battery controller (rapid Charging/Discharging flapping near full
# charge). ADP1/online is a plain file read that already reflects the physical
# pin state, so a short poll is instant, ordered and idempotent — no event
# storms, no duplicated "unplugged" notifications.

set -uo pipefail

AC_DEVICE="${AC_DEVICE:-ADP1}"
AC_PATH="/sys/class/power_supply/${AC_DEVICE}"
POLL_INTERVAL="${POLL_INTERVAL:-2}"
SETTLE_DELAY="${SETTLE_DELAY:-3}"
REFRESH_INTERVAL="${REFRESH_INTERVAL:-600}"

log() { printf '[battery-monitor] %s\n' "$*" >&2; }

notify_cmd="${BATTERY_NOTIFY_CMD:-}"
if [[ -z $notify_cmd ]]; then
    if command -v battery-notify.sh >/dev/null 2>&1; then
        notify_cmd=$(command -v battery-notify.sh)
    else
        notify_cmd="${HOME}/.local/bin/battery-notify.sh"
    fi
fi

if [[ ! -x $notify_cmd ]]; then
    log "notification script is missing or not executable: ${notify_cmd}"
    exit 1
fi

# Single instance per user session.
lock_file="${XDG_RUNTIME_DIR:-/tmp}/battery-monitor.lock"
exec 9>"$lock_file" || exit 1
if ! flock -n 9; then
    log "already running"
    exit 0
fi

ac_online() {
    local value
    value=$(cat "${AC_PATH}/online" 2>/dev/null) || return 1
    [[ $value == 0 || $value == 1 ]] || return 1
    printf '%s\n' "$value"
}

last=""
last_refresh=$(date +%s)

while :; do
    if current=$(ac_online); then
        if [[ -z $last ]]; then
            # First sample: adopt the state silently, nothing was "changed".
            last=$current
        elif [[ $current != "$last" ]]; then
            # Let the SMC settle, then only report transitions that hold.
            sleep "$SETTLE_DELAY"
            if settled=$(ac_online) && [[ $settled == "$current" ]]; then
                "$notify_cmd" || log "notification script failed"
            fi
            last=$current
        fi
    fi

    now=$(date +%s)
    if (( now - last_refresh >= REFRESH_INTERVAL )); then
        last_refresh=$now
        if [[ ${last:-1} == 0 ]]; then
            "$notify_cmd" || log "notification script failed"
        fi
    fi

    sleep "$POLL_INTERVAL"
done
