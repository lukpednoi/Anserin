#!/usr/bin/env bash
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../caching.sh"
QUERY="$1"
SESSION="$2"
SEARCH_DIR="$3"
CACHE_DIR="$4"
RUN_DIR="$5"
LOG_DIR="$6"
DDG_SCRIPT="$7"

mkdir -p "$LOG_DIR" "$RUN_DIR" "$SEARCH_DIR" "$CACHE_DIR"

export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/run/current-system/sw/bin:$HOME/.nix-profile/bin:$HOME/.local/bin

echo 'stop' > "$RUN_DIR/ddg_search_control"
mo_stop_tree "$QS_RUN_DIR/wallpaper-search.pid"
sleep 0.2

rm -rf "${SEARCH_DIR}"/* 2>/dev/null || true
rm -f "${CACHE_DIR}/search_map.txt" 2>/dev/null || true

echo "$SESSION" > "${CACHE_DIR}/current_search_session"
echo 'run' > "$RUN_DIR/ddg_search_control"

if [ -f "$DDG_SCRIPT" ]; then
    bash "$DDG_SCRIPT" "$QUERY" "$SESSION" >/dev/null 2>&1 &
    mo_pid_write "$QS_RUN_DIR/wallpaper-search.pid" "$!"
fi
