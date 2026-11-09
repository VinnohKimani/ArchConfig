#!/usr/bin/env bash
# display-switch.sh — Quick display projection & monitor mode selector (Super + P)
# Handles mirroring, extending, laptop-only, and external-only for projectors & TVs.

set -euo pipefail

# Find all external connected displays
EXTERNAL_MONITORS=()
for f in /sys/class/drm/card*-*/status; do
    if [[ -f "$f" && $(cat "$f" 2>/dev/null) == "connected" ]]; then
        conn=$(basename "$(dirname "$f")")
        name=${conn#*-}
        if [[ "$name" != "eDP-1" ]]; then
            EXTERNAL_MONITORS+=("$name")
        fi
    fi
done

notify() {
    notify-send -a "Display Mode" -i "video-display" "$1" "$2" 2>/dev/null || true
}

if [[ ${#EXTERNAL_MONITORS[@]} -eq 0 ]]; then
    choice=$(printf "Open Display Settings (nwg-displays)\nCancel" | rofi -dmenu -p "No External Monitor Detected" -lines 2)
    if [[ "$choice" == *"nwg-displays"* ]]; then
        nwg-displays &
    fi
    exit 0
fi

EXT="${EXTERNAL_MONITORS[0]}"

OPTIONS="󰍹  Mirror Screen (Clone to $EXT)\n󰍺  Extend Desktop (Dual Monitors)\n󰍹  Laptop Screen Only (Disable $EXT)\n󰍺  External Screen Only (Disable Laptop)\n  Display Settings (nwg-displays)"

CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu -p "Display Configuration ($EXT)" -lines 5)

case "$CHOICE" in
    *"Mirror Screen"*)
        # Reset internal monitor to native HiDPI
        hyprctl keyword monitor "eDP-1,2560x1600@60,0x0,1.6"
        # Mirror internal screen onto external display at integer 1x scale
        hyprctl keyword monitor "$EXT,preferred,auto,1,mirror,eDP-1"
        notify "Mirror Mode Activated" "Display cloned to $EXT for presentation"
        ;;
    *"Extend Desktop"*)
        hyprctl keyword monitor "eDP-1,2560x1600@60,0x0,1.6"
        hyprctl keyword monitor "$EXT,preferred,auto,1"
        notify "Extend Mode Activated" "Desktop extended to $EXT"
        ;;
    *"Laptop Screen Only"*)
        hyprctl keyword monitor "$EXT,disable"
        hyprctl keyword monitor "eDP-1,2560x1600@60,0x0,1.6"
        notify "Laptop Only" "External monitor $EXT disabled"
        ;;
    *"External Screen Only"*)
        hyprctl keyword monitor "$EXT,preferred,0x0,1"
        hyprctl keyword monitor "eDP-1,disable"
        notify "External Screen Only" "Laptop display disabled, using $EXT"
        ;;
    *"Display Settings"*)
        nwg-displays &
        ;;
    *)
        exit 0
        ;;
esac

