#!/usr/bin/env bash

[[ ${_ANSERIN_CACHING_READY:-} == 1 ]] && return 0

if [ -z "${ANSERIN_DIR:-}" ]; then
    SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
    export ANSERIN_DIR="$(dirname "$SCRIPT_DIR")"
fi

export QS_DIR="$ANSERIN_DIR/quickshell"
# Anserin's own helper program (src/quickshell/native/core, built by scripts/build-core.py when the shell starts)
export ANSERIN_CORE="$(dirname "$ANSERIN_DIR")/.lab-data/core-build/bin/anserin-core"
export MAIN_QML="$QS_DIR/Shell.qml"
: "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR must be set}"
export IPC_SOCKET="$XDG_RUNTIME_DIR/anserin/ipc.sock"

export QS_CACHE_DIR="$HOME/.cache/anserin"
export QS_STATE_DIR="$HOME/.local/state/anserin"
export QS_RUN_DIR="$XDG_RUNTIME_DIR/anserin"
umask 077
mkdir -p "$QS_RUN_DIR" || return 1
source "$ANSERIN_DIR/scripts/owned-process.sh"
export QS_LOG_DIR="$QS_RUN_DIR/logs"
export QS_SETTINGS="$HOME/.config/anserin/settings.json"

[[ -d "$QS_LOG_DIR" && -d "$QS_CACHE_DIR" && -d "$QS_STATE_DIR" ]] || mkdir -p "$QS_CACHE_DIR" "$QS_STATE_DIR" "$QS_RUN_DIR" "$QS_LOG_DIR"

qs_ensure_cache() {
    local WIDGET_NAME="$1"
    
    local WIDGET_UPPER="${WIDGET_NAME^^}"
    
    local WIDGET_CACHE="$QS_CACHE_DIR/$WIDGET_NAME"
    local WIDGET_STATE="$QS_STATE_DIR/$WIDGET_NAME"
    local WIDGET_RUN="$QS_RUN_DIR/$WIDGET_NAME"
    
    [[ -d "$WIDGET_RUN" && -d "$WIDGET_STATE" && -d "$WIDGET_CACHE" ]] || mkdir -p "$WIDGET_CACHE" "$WIDGET_STATE" "$WIDGET_RUN"
    
    export "QS_CACHE_${WIDGET_UPPER}=$WIDGET_CACHE"
    export "QS_STATE_${WIDGET_UPPER}=$WIDGET_STATE"
    export "QS_RUN_${WIDGET_UPPER}=$WIDGET_RUN"
}

if [ -d "$QS_DIR" ]; then
    for dir in "$QS_DIR"/*/; do
        [ -d "$dir" ] || continue
        
        dir_trimmed="${dir%/}"
        WIDGET_NAME="${dir_trimmed##*/}"
        
        qs_ensure_cache "$WIDGET_NAME"
    done
fi

qs_ensure_cache "focustime"

ver="$(cat "$ANSERIN_DIR/version.txt")" || return 1
if [[ "$(cat "$QS_STATE_DIR/version" 2>/dev/null)" != "ANSERIN_VERSION=\"$ver\"" ]]; then
    printf 'ANSERIN_VERSION="%s"\n' "$ver" > "$QS_STATE_DIR/version"
fi

[ -f "$QS_STATE_DIR/quickactions/palettes.json" ] || echo "[]" > "$QS_STATE_DIR/quickactions/palettes.json" || return 1
_ANSERIN_CACHING_READY=1
