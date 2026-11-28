#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
ANSERIN_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/caching.sh" 2>/dev/null || true
source "$SCRIPT_DIR/config.sh" 2>/dev/null || true

STATE_DIR="${QS_STATE_DIR:-$HOME/.local/state/anserin}"
FLAG_FILE="$STATE_DIR/first_launch.done"

check_status() {
    mkdir -p "$STATE_DIR"
    if [ -f "$FLAG_FILE" ]; then
        echo "SKIP"
        exit 0
    fi

    # the flag is written when the guide opens (--open-guide), so a launch that never got past the lock screen
    # shows it again next time
    WP_DIR=""
    if type get_setting >/dev/null 2>&1; then
        WP_DIR="$(get_setting "wallpaperDir" "")"
        [ -z "$WP_DIR" ] && WP_DIR="$(get_setting "wallpaper_dir" "")"
    fi

    RANDOM_WP=""
    if [ -n "$WP_DIR" ] && [ -d "$WP_DIR" ]; then
        RANDOM_WP="$(find "$WP_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.webm" \) 2>/dev/null | shuf -n 1)"
    fi

    echo "FIRST|$RANDOM_WP"
}

open_guide() {
    mkdir -p "$STATE_DIR" && touch "$FLAG_FILE"
    local script_path="$ANSERIN_DIR/scripts/qs_manager.sh"
    if [ -f "$script_path" ]; then
        bash "$script_path" open guide
    fi
}

reset_state() {
    rm -f "$FLAG_FILE"
}

case "$1" in
    --check)
        check_status
        ;;
    --open-guide)
        open_guide
        ;;
    --reset)
        reset_state
        ;;
    *)
        exit 1
        ;;
esac
