#!/usr/bin/env bash
scrDir=$(dirname "$(realpath "$0")")
source "$scrDir/globalcontrol.sh"
use_swayosd=false
isNotify=${BRIGHTNESS_NOTIFY:-true}

DEVICE="intel_backlight"

print_error() {
    local cmd
    cmd=$(basename "$0")
    cat <<EOF
    "$cmd" <action> [step]
    ...valid actions are...
        i -- <i>ncrease brightness [+5%]
        d -- <d>ecrease brightness [-5%]

    Example:
        "$cmd" i 10    # Increase brightness by 10%
        "$cmd" d       # Decrease brightness by default step (5%)
EOF
}

send_notification() {
    local action_label="$1"
    brightness=$(brightnessctl --device="$DEVICE" -m | grep -o '[0-9]\+%' | head -c-2)
    angle="$((((brightness + 2) / 5) * 5))"
    [ "$angle" -gt 100 ] && angle=100
    ico="$iconsDir/Wallbash-Icon/media/knob-$angle.svg"
    [[ $isNotify == true ]] && notify-send -a "HyDE Notify" -r 7 -t 1500 -h int:value:"$brightness" -i "$ico" "Screen Brightness" "${brightness}% (${action_label})"
}

get_brightness() {
    brightnessctl --device="$DEVICE" -m | grep -o '[0-9]\+%' | head -c-2
}

step=${BRIGHTNESS_STEPS:-5}
step="${2:-$step}"

case $1 in
i | -i)
    if [[ $(get_brightness) -lt 10 ]]; then
        step=1
    fi
    brightnessctl --device="$DEVICE" set +"$step"%
    send_notification "+${step}%"
    ;;
d | -d)
    if [[ $(get_brightness) -le 10 ]]; then
        step=1
    fi
    if [[ $(get_brightness) -le 1 ]]; then
        brightnessctl --device="$DEVICE" set "$step"%
    else
        brightnessctl --device="$DEVICE" set "$step"%-
    fi
    send_notification "-${step}%"
    ;;
*) print_error ;;
esac
