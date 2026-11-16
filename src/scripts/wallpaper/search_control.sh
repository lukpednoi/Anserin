#!/usr/bin/env bash
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../caching.sh"
ACTION="$1"
RUN_DIR="$2"

mkdir -p "$RUN_DIR"
echo "$ACTION" > "$RUN_DIR/ddg_search_control"

if [ "$ACTION" = "stop" ]; then
    mo_stop_tree "$QS_RUN_DIR/wallpaper-search.pid"
fi
