#!/usr/bin/env bash
scrDir=$(dirname "$(realpath "$0")")
source "$scrDir/globalcontrol.sh"
use_swayosd=false
isNotify=${BRIGHTNESS_NOTIFY:-true}

DEVICE="smc::kbd_backlight"

print_error() {
    local cmd
    cmd=$(basename "$0")
    cat <<EOF
    "$cmd" <action> [step]
    ...valid actions are...
        i -- <i>ncrease brightness [+10%]
        d -- <d>ecrease brightness [-10%]

    Example:
        "$cmd" i 10    # Increase brightness by 10%
        "$cmd" d       # Decrease brightness by default step (10%)
EOF
}

send_notification() {
    brightness=$(brightnessctl --device="$DEVICE" -m | grep -o '[0-9]\+%' | head -c-2)
    brightinfo="Keyboard"
    angle="$((((brightness + 2) / 5) * 5))"
    ico="$iconsDir/Wallbash-Icon/media/knob-$angle.svg"
    bar=$(seq -s "." $((brightness / 15)) | sed 's/[0-9]//g')
    [[ $isNotify == true ]] && notify-send -a "HyDE Notify" -r 8 -t 800 -i "$ico" "$brightness$bar" "$brightinfo"
}

get_brightness() {
    brightnessctl --device="$DEVICE" -m | grep -o '[0-9]\+%' | head -c-2
}

step=${BRIGHTNESS_STEPS:-10}
step="${2:-$step}"

case $1 in
i | -i)
    if [[ $(get_brightness) -lt 10 ]]; then
        step=5
    fi
    brightnessctl --device="$DEVICE" set +"$step"%
    send_notification
    ;;
d | -d)
    if [[ $(get_brightness) -le 10 ]]; then
        step=5
    fi
    if [[ $(get_brightness) -le 1 ]]; then
        brightnessctl --device="$DEVICE" set 0%
    else
        brightnessctl --device="$DEVICE" set "$step"%-
    fi
    send_notification
    ;;
*) print_error ;;
esac
