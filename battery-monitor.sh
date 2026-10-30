#!/usr/bin/env bash
# battery-monitor.sh — realtime charger plug/unplug notifications.
#
# Latency design:
#   * Primary: block on the kernel's `power_supply` uevent stream
#     (`udevadm monitor`), so a pin change wakes this loop immediately instead of
#     being discovered by a timer. This costs no CPU while waiting.
#   * Fallback tick: the same blocking read uses a short timeout, so even if no
#     uevent ever arrives (missing udev rule, driver quirk, machine resumed from
#     sleep) the AC pin is re-read every POLL_INTERVAL (250ms). Worst-case
#     latency stays under a quarter second, which reads as instant.
#   * No settle delay: the old 3s hold existed to filter the degraded battery
#     controller flapping between Charging/Discharging in BAT0/status. ADP1/online
#     is a physical pin state and does not flap, and duplicate uevents are
#     collapsed by comparing the value rather than the event.
#
# This daemon never suspends, locks or blanks anything. Its only side effect is
# a notification.

set -uo pipefail

POWER_SUPPLY_DIR="${POWER_SUPPLY_DIR:-/sys/class/power_supply}"
AC_DEVICE="${AC_DEVICE:-ADP1}"
AC_PATH="${POWER_SUPPLY_DIR}/${AC_DEVICE}"
POLL_INTERVAL="${POLL_INTERVAL:-0.25}"
REFRESH_INTERVAL="${REFRESH_INTERVAL:-600}"
RESUME_GAP="${RESUME_GAP:-30}"

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

# Event source. `coproc` keeps the reader in this process, so each loop
# iteration is a builtin `read` with a timeout: no forks, no polling load.
UDEV_FD=""
UDEV_PID=""
if command -v udevadm >/dev/null 2>&1; then
    coproc UDEV_LISTENER { exec udevadm monitor --subsystem-match=power_supply --property 2>/dev/null; }
    UDEV_FD=${UDEV_LISTENER[0]}
    UDEV_PID=${UDEV_LISTENER_PID:-}
    log "event-driven on power_supply uevents; ${POLL_INTERVAL}s fallback tick"
else
    log "udevadm not found; polling ${AC_PATH}/online every ${POLL_INTERVAL}s"
fi

send() {
    "$notify_cmd" || log "notification script failed"
}

last=""
last_tick=$SECONDS
last_refresh=$SECONDS

while :; do
    if [[ -n $UDEV_FD ]] && kill -0 "${UDEV_PID:-0}" 2>/dev/null; then
        # Blocks until a uevent line or the tick timeout, whichever comes first.
        IFS= read -r -t "$POLL_INTERVAL" -u "$UDEV_FD" _event || true
    else
        sleep "$POLL_INTERVAL"
    fi

    now=$SECONDS

    # A wall-clock jump means the machine was asleep. Adopt the current state
    # silently so waking up does not replay a stale transition.
    if (( now - last_tick > RESUME_GAP )); then
        last=""
        last_refresh=$now
        log "resume detected; re-syncing AC state silently"
    fi
    last_tick=$now

    if current=$(ac_online); then
        if [[ -z $last ]]; then
            last=$current
        elif [[ $current != "$last" ]]; then
            send
            last=$current
        fi
    fi

    if (( now - last_refresh >= REFRESH_INTERVAL )); then
        last_refresh=$now
        [[ ${last:-1} == 0 ]] && send
    fi
done
