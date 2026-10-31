#!/usr/bin/env bash
# battery-fix.sh — locate and disarm the old "Battery Critically Low ... will
# execute systemctl suspend in N" notifier, then install the fixed trio
# (battery-notify.sh, battery-monitor.sh, safe-suspend.sh).
#
# Why this exists: the repository fix replaces the scripts, but the machine can
# still be running a second, older countdown notifier (its popup reads
# "43% is critically low. Device will execute systemctl suspend in 1:56") whose
# threshold comparison is broken and whose timer suspends the laptop. Until that
# file's suspend call is removed and its daemon is killed, the unplug bug
# survives the upgrade.
#
# Usage:
#   ./battery-fix.sh --dry-run   # report only, change nothing (default-safe review)
#   ./battery-fix.sh             # back up, disarm, install, restart
#
# Every file it edits is copied to ~/.local/state/battery-fix/<timestamp>/ first.
# It never deletes anything in your home directory.

set -uo pipefail

DRY_RUN=0
[[ ${1:-} == "--dry-run" ]] && DRY_RUN=1

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/battery-fix"
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="${STATE_ROOT}/${STAMP}"
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/battery-monitor.log"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Text that identifies the offending notifier. "systemctl suspend" is checked
# separately, line by line, so a file only has to match one of these to be
# treated as a battery notifier.
OFFENDER_MARKERS='Battery Critically Low|will execute systemctl suspend|batterynotify|CRITICAL_PERCENT|BATTERY_CRITICAL'
SUSPEND_CALLS='systemctl[[:space:]]+(suspend|hibernate|hybrid-sleep)|loginctl[[:space:]]+suspend|pm-suspend|rtcwake[[:space:]]+-m'

USER_ROOTS=(
    "${HOME}/.local/bin"
    "${HOME}/bin"
    "${HOME}/.config/hypr"
    "${HOME}/.config/autostart"
    "${HOME}/.local/share/hyde"
    "${HOME}/.local/lib/hyde"
)
ROOT_ROOTS=("/usr/local/bin" "/etc/systemd/system")

changed=0
found_offenders=0
DISARM_DATE=$(date +%F)

say() { printf '%s\n' "$*"; }
note() { printf '[battery-fix] %s\n' "$*"; }

# Live power calls in a file: numbered lines, excluding comments and message
# lines. A notification that *mentions* "systemctl suspend in 1:56" is text, not
# an action, and is what identifies the offending script later.
power_call_lines() {
    awk -v pat="$SUSPEND_CALLS" '
        { trimmed = $0; sub(/^[ \t]+/, "", trimmed) }
        trimmed !~ /^#/ && $0 ~ pat && $0 !~ /(notify-send|printf|echo)/ { printf "%d:%s\n", NR, $0 }
    ' "$1"
}

count_power_calls() {
    local n
    n=$(power_call_lines "$1" | wc -l)
    printf '%s\n' "$((n + 0))"
}

backup() {
    local file=$1
    [[ -d $BACKUP_DIR ]] || mkdir -p "$BACKUP_DIR"
    local target="${BACKUP_DIR}${file}"
    mkdir -p "$(dirname "$target")"
    cp -p "$file" "$target" && note "backed up ${file} -> ${target}"
}

find_offenders() {
    local root
    for root in "${USER_ROOTS[@]}"; do
        [[ -d $root ]] || continue
        grep -rlE "$OFFENDER_MARKERS" "$root" 2>/dev/null
    done
}

disarm_file() {
    local file=$1
    local hits
    hits=$(count_power_calls "$file")
    if [[ ${hits:-0} -eq 0 ]]; then
        note "no live suspend/hibernate call in ${file} (countdown targets a helper?)"
        return 0
    fi

    say ""
    say "  ${file}: ${hits} power call(s) about to be disabled"
    power_call_lines "$file" | sed 's/^/    /'

    if (( DRY_RUN )); then
        return 0
    fi

    backup "$file"
    # Comment out live (non-comment) power calls. Message lines that merely
    # mention "systemctl suspend in 1:56" (notify-send/echo/printf) are kept:
    # they are how you recognise the script next time.
    awk -v pat="$SUSPEND_CALLS" -v stamp="$DISARM_DATE" '
        {
            trimmed = $0
            sub(/^[ \t]+/, "", trimmed)
            message = ($0 ~ /(notify-send|printf|echo)/)
            if (trimmed !~ /^#/ && $0 ~ pat && !message) {
                match($0, /^[ \t]*/)
                indent = substr($0, 1, RLENGTH)
                print indent "# [battery-fix disabled " stamp "] " substr($0, RLENGTH + 1)
            } else {
                print $0
            }
        }' "$file" > "${file}.battery-fix.tmp" && mv "${file}.battery-fix.tmp" "$file"

    local remaining
    remaining=$(count_power_calls "$file")
    if [[ ${remaining:-0} -ne 0 ]]; then
        note "WARNING: ${remaining} power call(s) still live in ${file} — review it manually"
    else
        note "disarmed ${file}"
    fi
    changed=$((changed + 1))
}

# Stop daemons whose *argv* points at a script path containing PATTERN.
# A plain `pkill -f PATTERN` also matches anything that merely mentions the name
# — including this script's own parent shell and a `bash -c '...'` wrapper — so
# the match is restricted to path-like arguments and our own process tree is
# excluded explicitly (that self-kill was observed during testing).
stop_offender() {
    local pattern=$1 pid arg cmd moved=0
    for pid in $(pgrep -f "$pattern" 2>/dev/null || true); do
        (( pid == $$ || pid == $PPID )) && continue
        cmd=$(tr '\0' ' ' <"/proc/${pid}/cmdline" 2>/dev/null) || continue
        [[ -z $cmd ]] && continue
        [[ $cmd == *battery-fix* ]] && continue
        for arg in $cmd; do
            if [[ $arg == */* && $arg == *"$pattern"* ]]; then
                if kill "$pid" 2>/dev/null; then
                    note "stopped pid ${pid} (${arg##*/})"
                    moved=1
                fi
                break
            fi
        done
    done
    (( moved == 0 )) && note "no running process for '${pattern}'"
    return 0
}

say "=== 1. Searching for the old countdown notifier ==="
mapfile -t offenders < <(find_offenders | sort -u)
if (( ${#offenders[@]} == 0 )); then
    say "  none found in ${USER_ROOTS[*]}"
else
    printf '  %s\n' "${offenders[@]}"
    found_offenders=${#offenders[@]}
fi

say ""
say "=== 2. Disabling its power calls ==="
for file in "${offenders[@]}"; do
    disarm_file "$file"
done

say ""
say "=== 3. Root-owned copies (need sudo) ==="
for root in "${ROOT_ROOTS[@]}"; do
    [[ -d $root ]] || continue
    while IFS= read -r file; do
        grep -lE "$OFFENDER_MARKERS" "$file" >/dev/null 2>&1 || continue
        say "  ${file} — inspect with: sudo grep -nE '${SUSPEND_CALLS}' '${file}'"
        root_hits=$(( ${root_hits:-0} + 1 ))
    done < <(find "$root" -maxdepth 2 -type f 2>/dev/null)
done
(( ${root_hits:-0} > 0 )) && note "root-owned matches must be edited with sudo; this script does not touch them"

if (( DRY_RUN )); then
    say ""
    say "=== Dry run: nothing was changed. Re-run without --dry-run to apply. ==="
    exit 0
fi

say ""
say "=== 4. Stopping the old daemons ==="
stop_offender 'batterynotify'
stop_offender 'battery-notify-daemon'
stop_offender 'battery-monitor.sh'

say ""
say "=== 5. Installing the fixed scripts ==="
for script in battery-notify.sh battery-monitor.sh safe-suspend.sh; do
    if [[ -f "${SCRIPT_DIR}/${script}" ]]; then
        install -D -m 0755 "${SCRIPT_DIR}/${script}" "${BIN_DIR}/${script}" &&
            note "installed ${BIN_DIR}/${script}"
    else
        note "missing source ${SCRIPT_DIR}/${script} — run this from the repo root"
    fi
done

say ""
say "=== 6. Pointing hypridle at safe-suspend.sh ==="
for conf in "${HOME}/.config/hypr/hypridle.conf" "${HOME}/.config/hypr/hyprland.conf"; do
    [[ -f $conf ]] || continue
    if grep -qE 'on-timeout[[:space:]]*=[[:space:]]*systemctl[[:space:]]+suspend' "$conf"; then
        backup "$conf"
        sed -i -E 's|^([[:space:]]*on-timeout[[:space:]]*=[[:space:]]*)systemctl[[:space:]]+suspend.*$|\1~/.local/bin/safe-suspend.sh|' "$conf"
        note "patched suspend listener in ${conf}"
        changed=$((changed + 1))
    fi
    if grep -qE 'batterynotify|battery-notify\.sh' "$conf"; then
        backup "$conf"
        sed -i -E '/batterynotify|battery-notify\.sh/ s|^([[:space:]]*)(exec|exec-once|bind)|\1# [battery-fix] \2|' "$conf"
        note "disabled old notifier autostart in ${conf} (see backup)"
        changed=$((changed + 1))
    fi
done

if [[ -f "${HOME}/.config/hypr/hyprland.lua" ]]; then
    grep -qE 'batterynotify|battery-notify' "${HOME}/.config/hypr/hyprland.lua" 2>/dev/null &&
        note "hyprland.lua still references the old notifier — edit it by hand (Lua autostart line)"
fi

say ""
say "=== 7. Starting the AC monitor ==="
if [[ -x "${BIN_DIR}/battery-monitor.sh" ]]; then
    mkdir -p "$(dirname "$LOG_FILE")"
    nohup "${BIN_DIR}/battery-monitor.sh" >>"$LOG_FILE" 2>&1 &
    sleep 1
    if pgrep -f 'battery-monitor.sh' >/dev/null; then
        note "battery-monitor.sh running (log: ${LOG_FILE})"
    else
        note "battery-monitor.sh failed to stay up — check ${LOG_FILE}"
    fi
fi

say ""
say "=== Summary ==="
say "  offenders found : ${found_offenders}"
say "  files changed   : ${changed}"
(( changed > 0 )) && say "  backups         : ${BACKUP_DIR}"
cat <<'NEXT'

Next steps:
  1. hyprctl reload            # re-read hypridle/hyprland config
  2. Unplug the charger and confirm you get ONE "Charger disconnected"
     notification and no "critically low" countdown.
  3. If the countdown still appears, it is running from a root-owned copy:
     sudo grep -rlE 'Battery Critically Low|will execute systemctl suspend' /usr/local/bin /etc
  4. Check what actually asked for the last suspend:
     journalctl -b | grep -iE 'suspended|suspend' | tail -30
NEXT
