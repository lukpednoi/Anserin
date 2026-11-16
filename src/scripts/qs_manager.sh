#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == */* ]]; then
    SCRIPT_DIR="$(cd -- "${BASH_SOURCE[0]%/*}" 2>/dev/null && pwd -P)"
else
    SCRIPT_DIR="$(pwd -P)"
fi

source "$SCRIPT_DIR/caching.sh" 2>/dev/null || true
source "$SCRIPT_DIR/config.sh" 2>/dev/null || true
source "$SCRIPT_DIR/i18n.sh" 2>/dev/null || true

ACTION="$1"
TARGET="$2"
SUBTARGET="$3"

send_qs_ipc() {
    if [[ -n "$MAIN_QML" ]]; then
        quickshell -p "$MAIN_QML" ipc call main handleCommand "$@" >/dev/null 2>&1
    else
        quickshell ipc call main handleCommand "$@" >/dev/null 2>&1
    fi
}

log_widget_launch() {
    local target="$1"
    [[ -z "$target" ]] && return

    local rank_script="$SCRIPT_DIR/../quickshell/launcher/app_rank.py"
    [[ -f "$rank_script" ]] || rank_script="$ANSERIN_DIR/quickshell/launcher/app_rank.py"

    local app_name="$target"
    if command -v t &>/dev/null; then
        case "$target" in
            wallpaper) app_name="$(t "widgets.wallpaper.name")" ;;
            network) app_name="$(t "widgets.network.name")" ;;
            volume) app_name="$(t "widgets.volume.name")" ;;
            guide) app_name="$(t "widgets.guide.name")" ;;
            calendar) app_name="$(t "widgets.calendar.name")" ;;
            music) app_name="$(t "widgets.music.name")" ;;
            notifications) app_name="$(t "widgets.notifications.name")" ;;
            system) app_name="$(t "widgets.system.name")" ;;
        esac
    fi

    if [[ -f "$rank_script" ]]; then
        python3 "$rank_script" --log-launch --name "$target" >/dev/null 2>&1 &
        if [[ -n "$app_name" && "$app_name" != "$target" && "$app_name" != "widgets."* ]]; then
            python3 "$rank_script" --log-launch --name "$app_name" >/dev/null 2>&1 &
        fi
    fi
}

if [[ "$ACTION" == "workspace" ]]; then
    if [[ "$2" =~ ^[0-9]+$ ]]; then
        ACTION="$2"
        TARGET="$3"
        SUBTARGET="$4"
    elif [[ "$3" =~ ^[0-9]+$ ]]; then
        ACTION="$3"
        TARGET="$2"
        SUBTARGET="$4"
    elif [[ "$4" =~ ^[0-9]+$ ]]; then
        ACTION="$4"
        TARGET="$2"
        SUBTARGET="$3"
    else
        ACTION="$2"
        TARGET="$3"
        SUBTARGET="$4"
    fi
fi

if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
    if (( ACTION < 1 )); then
        exit 0
    fi

    DE="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
    DE="${DE,,}"

    if [[ "$DE" == *"niri"* ]] || [[ -n "${NIRI_SOCKET:-}" ]]; then
        if [[ "$TARGET" == "move" ]]; then
            niri msg action move-window-to-workspace "$ACTION" >/dev/null 2>&1 &
        else
            niri msg action focus-workspace "$ACTION" >/dev/null 2>&1 &
        fi
    elif [[ "$DE" == *"sway"* ]] || [[ -n "${SWAYSOCK:-}" ]]; then
        if [[ "$TARGET" == "move" ]]; then
            swaymsg move container to workspace number "$ACTION" >/dev/null 2>&1 &
        else
            swaymsg workspace number "$ACTION" >/dev/null 2>&1 &
        fi
    else
        if [[ "$TARGET" == "move" ]]; then
            hyprctl dispatch movetoworkspace "$ACTION" >/dev/null 2>&1 || hyprctl dispatch 'hl.dsp.window.move({ workspace = "'"$ACTION"'" })' >/dev/null 2>&1 &
        else
            hyprctl dispatch workspace "$ACTION" >/dev/null 2>&1 || hyprctl dispatch 'hl.dsp.focus({ workspace = "'"$ACTION"'" })' >/dev/null 2>&1 &
        fi
    fi

    send_qs_ipc "close" "" "" &

    exit 0
fi

QS_NETWORK_CACHE="$QS_CACHE_NETWORK"
NETWORK_MODE_FILE="$QS_NETWORK_CACHE/mode"

QS_GUIDE_CACHE="$QS_CACHE_GUIDE"
GUIDE_MODE_FILE="$QS_GUIDE_CACHE/last_tab.txt"

if [[ "$ACTION" == "close" ]]; then
    send_qs_ipc "close" "" ""
    exit 0
fi

if [[ "$ACTION" == "open" || "$ACTION" == "toggle" ]]; then
    log_widget_launch "$TARGET" &
    case "$TARGET" in
        network)
            [[ -d "$QS_NETWORK_CACHE" ]] || mkdir -p "$QS_NETWORK_CACHE"
            [[ -n "$SUBTARGET" ]] && echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
            ;;
        guide)
            [[ -d "$QS_GUIDE_CACHE" ]] || mkdir -p "$QS_GUIDE_CACHE"
            [[ -n "$SUBTARGET" ]] && echo "$SUBTARGET" > "$GUIDE_MODE_FILE"
            ;;
        wallpaper)
            SUBTARGET=""
            ;;
    esac
    send_qs_ipc "$ACTION" "$TARGET" "$SUBTARGET"
    exit 0
fi
