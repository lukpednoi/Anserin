#!/usr/bin/env bash
# `anserin -up`: update this Anserin copy from GitHub and offer to restart it.
# Your settings in ~/.config/anserin are not touched.
set -euo pipefail

ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd)"
say()  { printf '\033[1;35m::\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }
ask()  { local reply; read -r -p "$1 [y/N] " reply </dev/tty || return 1; [[ "$reply" =~ ^[Yy]$ ]]; }

[[ -d "$ROOT/.git" ]] || die "$ROOT is not a git checkout, so it cannot update itself. Reinstall with install/install.sh."
git -C "$ROOT" diff --quiet HEAD -- || die "$ROOT has local changes to Anserin's files; nothing was updated."
git -C "$ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 \
    || die "This branch does not follow a GitHub branch; nothing was updated."

before="$(cat "$ROOT/version.txt")"
old_head="$(git -C "$ROOT" rev-parse HEAD)"
say "Checking for updates…"
git -C "$ROOT" pull --ff-only --quiet || die "The update could not be applied cleanly; nothing was changed."
if [[ "$(git -C "$ROOT" rev-parse HEAD)" == "$old_head" ]]; then
    say "Anserin $before is already up to date."
    exit 0
fi
say "Updated Anserin $before → $(cat "$ROOT/version.txt")"

source "$ROOT/src/scripts/owned-process.sh"
QS_RUN_DIR="$(realpath -m "${XDG_RUNTIME_DIR:-/run/user/$UID}/anserin")"
QS_CACHE_DIR="$HOME/.cache/anserin"
if mo_pid_valid "$QS_RUN_DIR/anserind.pid" 2>/dev/null; then
    if ask "Anserin is running. Restart it now to use the update?"; then
        "$ROOT/bin/anserin" -end && "$ROOT/bin/anserin" -start
    else
        say "The update is used the next time Anserin starts (anserin -end, then anserin -start)."
    fi
fi
