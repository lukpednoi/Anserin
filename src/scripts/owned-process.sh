#!/usr/bin/env bash

# A saved Linux start time prevents stale PID files from targeting a reused PID.
mo_process_start() {
    local stat
    [[ "$1" =~ ^[0-9]+$ && "$1" -gt 1 && -O /proc/$1 ]] || return 1
    IFS= read -r stat < "/proc/$1/stat" 2>/dev/null || return 1
    stat=${stat##*) }
    local fields=($stat)
    [[ ${fields[0]} != Z ]] || return 1
    printf '%s\n' "${fields[19]}"
}

mo_pid_write() {
    local start
    start=$(mo_process_start "$2") || return 1
    printf '%s\n' "$start" > "$1.start"
    printf '%s\n' "$2" > "$1"
}

mo_pid_valid() {
    local pid start current file
    file=$(realpath -m -- "$1") || return 1
    [[ "$file" == "$QS_RUN_DIR/"* || "$file" == "$QS_CACHE_DIR/"* ]] || return 1
    [[ -f "$1" && -O "$1" && ! -L "$1" && -f "$1.start" && -O "$1.start" && ! -L "$1.start" ]] || return 1
    IFS= read -r pid < "$1" || return 1
    IFS= read -r start < "$1.start" || return 1
    [[ "$start" =~ ^[0-9]+$ ]] || return 1
    current=$(mo_process_start "$pid") || return 1
    [[ "$current" == "$start" ]]
}

mo_pid_signal() {
    mo_pid_valid "$1" || return 0
    local pid
    IFS= read -r pid < "$1"
    kill "-${2:-TERM}" "$pid" 2>/dev/null || true
}

mo_stop_children() {
    mo_pid_valid "$1" || return 0
    local pid children="" child child_file
    IFS= read -r pid < "$1"
    IFS= read -r children < "/proc/$pid/task/$pid/children" || true
    for child in $children; do
        child_file="$1.child-$child"
        if mo_pid_write "$child_file" "$child"; then
            mo_stop_tree "$child_file"
        fi
    done
}

mo_stop_tree() {
    mo_pid_valid "$1" || return 0
    local pid i
    IFS= read -r pid < "$1"
    [[ "$pid" != "$$" ]] || return 1
    mo_stop_children "$1"
    mo_pid_signal "$1" TERM
    for ((i=0; i<20; i++)); do
        mo_pid_valid "$1" || break
        sleep 0.1
    done
    mo_pid_signal "$1" KILL
}
