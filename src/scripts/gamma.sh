#!/usr/bin/env bash
# Night light through Anserin core's gamma daemon (anserin-core gamma). blue_light_filter.sh hands over here when
# the core is built, after stopping the wl-gammarelay-rs it started itself (by its own PID file).
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
set -euo pipefail

TEMP_MIN=1000
TEMP_MAX=10000
DAY_TEMP=6500
FALLBACK_DAY_START="06:30"
FALLBACK_NIGHT_START="19:00"
GAMMARELAY_PATTERN='^([^ ]*/)?wl-gammarelay-rs( |$)'

VERBOSE=0
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

if [[ ${#ARGS[@]} -gt 0 ]]; then
    set -- "${ARGS[@]}"
else
    set --
fi

log() {
    if [[ "$VERBOSE" -eq 1 ]]; then
        echo "[verbose] $*" >&2
    fi
}

usage() {
    exit 1
}

gamma() {
    if [[ "$VERBOSE" -eq 1 ]]; then
        "$ANSERIN_CORE" gamma "$@"
    else
        "$ANSERIN_CORE" gamma "$@" 2>/dev/null
    fi
}

gamma_installed() {
    if ! [[ -x "$ANSERIN_CORE" ]]; then
        log "the Night light daemon is not installed."
        return 1
    fi
}

gamma_running() {
    gamma_installed 2>/dev/null && "$ANSERIN_CORE" gamma status >/dev/null 2>&1
}

target_args() {
    local output="${1:-}"
    TARGET=()
    if [[ -n "$output" ]]; then
        TARGET=(--output "$output")
    fi
}

gamma_start() {
    gamma_installed || return 1
    gamma_running && return 0

    # a wl-gammarelay-rs not started by Anserin is left alone (never signalled by name)
    if pgrep -f "$GAMMARELAY_PATTERN" >/dev/null 2>&1; then
        log "wl-gammarelay-rs still holds the gamma control; the Night light daemon may not take effect."
    fi

    log "Starting the Night light daemon."
    gamma start
}

gamma_stop() {
    [[ -x "$ANSERIN_CORE" ]] || return 0
    log "Stopping the Night light daemon."
    gamma quit
}

gamma_set_manual() {
    local temp="$1" output="${2:-}"
    gamma_start || return 1
    target_args "$output"

    log "Setting manual temperature $temp on ${output:-every output}."
    gamma set "${TARGET[@]}" --temperature "$temp"
}

gamma_set_auto() {
    local temp="$1" output="${2:-}" lat="${3:-0}" lon="${4:-0}"
    gamma_start || return 1
    target_args "$output"

    if awk -v lat="$lat" -v lon="$lon" 'BEGIN { exit !(lat == 0 && lon == 0) }'; then
        gamma location clear || return 1
    else
        gamma location "$lat" "$lon" || return 1
    fi

    log "Following the schedule on ${output:-every output} (night_temp=$temp lat=$lat lon=$lon)."
    gamma fallback "$FALLBACK_DAY_START" "$FALLBACK_NIGHT_START" &&
        gamma auto on "${TARGET[@]}" --day "$DAY_TEMP" --night "$temp"
}

gamma_reset() {
    local output="${1:-}"
    gamma_running || return 0
    target_args "$output"

    log "Resetting ${output:-every output} to neutral temperature and full brightness."
    gamma reset "${TARGET[@]}"
}

gamma_status() {
    local output="${1:-}"
    if ! gamma_running; then
        echo "stopped"
        return
    fi

    if [[ "$VERBOSE" -eq 1 ]]; then
        target_args "$output"
        local line
        while IFS= read -r line; do
            [[ "$line" == "running" ]] || log "$line"
        done < <(gamma status "${TARGET[@]}" || true)
    fi

    echo "running"
}

[[ $# -ge 1 ]] || usage

CMD="$1"
shift

case "$CMD" in
    set)
        [[ $# -ge 1 ]] || usage
        temp="$1"
        output="${2:-}"
        mode="${3:-manual}"
        lat="${4:-0}"
        lon="${5:-0}"
        if ! [[ "$temp" =~ ^[0-9]+$ ]] || (( temp < TEMP_MIN || temp > TEMP_MAX )); then
            log "Temperature $temp is outside valid range ($TEMP_MIN-$TEMP_MAX)."
            exit 1
        fi
        if ! [[ "$lat" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || ! [[ "$lon" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
            log "Latitude '$lat' or longitude '$lon' is not a valid number."
            exit 1
        fi
        if [[ "$mode" == "auto" ]]; then
            gamma_set_auto "$temp" "$output" "$lat" "$lon"
        else
            gamma_set_manual "$temp" "$output"
        fi
        ;;
    reset)
        gamma_reset "${1:-}"
        ;;
    status)
        gamma_status "${1:-}"
        ;;
    start)
        gamma_start
        ;;
    stop)
        gamma_stop
        ;;
    *)
        usage
        ;;
esac
