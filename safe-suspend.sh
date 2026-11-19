#!/usr/bin/env bash
# safe-suspend.sh — the only sanctioned path to S3 on this machine.
#
# Referenced by the hypridle suspend listener and by the lid-switch binding.
# Every other config must call this script instead of `systemctl suspend`, so
# that a suspend can only ever be granted on purpose and never as a side effect
# of the charger being unplugged.
#
# Policy (fails safe: any doubt means no suspend):
#   AC plugged in                  -> suspend
#   on battery, level >= threshold -> suspend
#   on battery, level <  threshold -> block and warn (voltage sag on this worn
#                                     battery kills the machine on wake)
#   AC or level unreadable         -> block and warn

set -uo pipefail

POWER_SUPPLY_DIR="${POWER_SUPPLY_DIR:-/sys/class/power_supply}"
BAT_DEVICE="${BAT_DEVICE:-BAT0}"
AC_DEVICE="${AC_DEVICE:-ADP1}"
BAT_PATH="${POWER_SUPPLY_DIR}/${BAT_DEVICE}"
AC_PATH="${POWER_SUPPLY_DIR}/${AC_DEVICE}"
MIN_SUSPEND_PERCENT="${MIN_SUSPEND_PERCENT:-5}"
APP_NAME="HyDE Alert"

log() { printf '[safe-suspend] %s\n' "$*" >&2; }

block() {
    log "suspend blocked: $*"
    notify-send -a "$APP_NAME" -u critical -i "battery-caution-symbolic" \
        "Suspend blocked" "$*" 2>/dev/null || true
    exit 0
}

ac_online() {
    local value
    value=$(cat "${AC_PATH}/online" 2>/dev/null) || return 1
    [[ $value == 0 || $value == 1 ]] || return 1
    printf '%s\n' "$value"
}

battery_capacity() {
    local value
    value=$(cat "${BAT_PATH}/capacity" 2>/dev/null) || return 1
    [[ $value =~ ^[0-9]{1,3}$ ]] || return 1
    (( value <= 100 )) || return 1
    printf '%s\n' "$value"
}

# Fast capacity read with retries. Eliminates the sleep race condition
# where a 2-second delay got frozen by system suspend mid-execution and
# falsely failed upon resume.
stable_capacity() {
    local attempt value
    for attempt in 1 2 3; do
        if value=$(battery_capacity) && (( value > 0 )); then
            printf '%s\n' "$value"
            return 0
        fi
        sleep 0.1
    done
    return 1
}

if ! online=$(ac_online); then
    block "AC adapter state unreadable (${AC_PATH}/online)"
fi

if [[ $online == 1 ]]; then
    exec systemctl suspend
fi

if ! capacity=$(stable_capacity); then
    block "battery level unreadable or unstable (${BAT_PATH}/capacity)"
fi

if (( capacity < MIN_SUSPEND_PERCENT )); then
    block "${capacity}% on battery (minimum ${MIN_SUSPEND_PERCENT}%) — plug in first"
fi

exec systemctl suspend
