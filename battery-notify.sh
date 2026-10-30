#!/usr/bin/env bash
# battery-notify.sh — charger / battery state notifications.
#
# NOTIFICATION-ONLY BY DESIGN. This script must never call `systemctl suspend`,
# `loginctl`, `hyprctl dispatch dpms` or any other power action. Suspending is
# the sole job of safe-suspend.sh.
#
# Regression this guards against (the reason the laptop slept when the charger
# was pulled): the old script computed the level from
# energy_now / energy_full_design instead of reading BAT0/capacity. On this
# degraded battery that ratio is always far too low (~22% while Waybar and
# UPower both said ~72%), so its "battery critical -> protect the session"
# branch fired on every AC unplug and put the machine to sleep even at 70%+.
# Keep this file free of power calls.

set -uo pipefail

BAT_DEVICE="${BAT_DEVICE:-BAT0}"
AC_DEVICE="${AC_DEVICE:-ADP1}"
BAT_PATH="/sys/class/power_supply/${BAT_DEVICE}"
AC_PATH="/sys/class/power_supply/${AC_DEVICE}"
LOW_BATTERY_PERCENT="${LOW_BATTERY_PERCENT:-15}"
APP_NAME="HyDE Notify"
REPLACE_ID=923

log() { printf '[battery-notify] %s\n' "$*" >&2; }

# 1 = charger in, 0 = on battery, non-zero exit = unknown.
ac_online() {
    local value
    value=$(cat "${AC_PATH}/online" 2>/dev/null) || return 1
    [[ $value == 0 || $value == 1 ]] || return 1
    printf '%s\n' "$value"
}

# Kernel-reported level (the same number Waybar and UPower show).
battery_capacity() {
    local value
    value=$(cat "${BAT_PATH}/capacity" 2>/dev/null) || return 1
    [[ $value =~ ^[0-9]{1,3}$ ]] || return 1
    (( value <= 100 )) || return 1
    printf '%s\n' "$value"
}

icon_for_capacity() {
    local capacity=$1
    if (( capacity <= LOW_BATTERY_PERCENT )); then
        printf 'battery-caution-symbolic'
    elif (( capacity <= 40 )); then
        printf 'battery-low-symbolic'
    elif (( capacity <= 75 )); then
        printf 'battery-good-symbolic'
    else
        printf 'battery-full-symbolic'
    fi
}

online=$(ac_online) || { log "cannot read ${AC_PATH}/online — no notification"; exit 0; }
capacity=$(battery_capacity) || { log "cannot read ${BAT_PATH}/capacity — no notification"; exit 0; }

if [[ $online == 1 ]]; then
    notify-send -a "$APP_NAME" -r "$REPLACE_ID" -u low \
        -i "battery-full-charging-symbolic" \
        "Charger connected" "${capacity}% · charging"
elif (( capacity <= LOW_BATTERY_PERCENT )); then
    notify-send -a "$APP_NAME" -r "$REPLACE_ID" -u critical \
        -i "battery-caution-symbolic" \
        "Battery low — charger disconnected" "${capacity}% remaining, plug in now"
else
    notify-send -a "$APP_NAME" -r "$REPLACE_ID" -u normal \
        -i "$(icon_for_capacity "$capacity")" \
        "Charger disconnected" "${capacity}% remaining"
fi

exit 0
