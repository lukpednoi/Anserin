#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/owned-process.sh"

ROOT="$(dirname "$ANSERIN_DIR")"

# Clean process restart when managed by anserind so Mesa/Qt heap resets completely without locking the screen.
# setsid detaches the restart runner from anserind's session so `anserind stop` never terminates it mid-flight.
if mo_pid_valid "$QS_RUN_DIR/anserind.pid" 2>/dev/null; then
    setsid bash -c '
        sleep 0.15
        "$1/bin/anserind" stop >/dev/null 2>&1
        export XDG_CACHE_HOME="$HOME/.cache/anserin"
        "$1/bin/anserind" start >>"$2/fork.log" 2>&1 &
    ' _ "$ROOT" "$QS_RUN_DIR" </dev/null >/dev/null 2>&1 &
    exit 0
fi

# Fallback when Quickshell was started directly without anserind (e.g. sandbox / manual dev run).
quickshell -p "$MAIN_QML" ipc call main forceReload
