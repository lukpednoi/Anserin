#!/usr/bin/env bash
# Remove Anserin from this computer: the shell, its command, its settings, state and cache, and the lines
# install.sh added to your Hyprland config. Packages are left installed (other programs may use them).
# It lists everything first and asks before removing anything.
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/anserin"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/anserin"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/anserin"
RUN_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}/anserin"
BIN_DIR="$HOME/.local/bin"
DEFAULT_DIR="$HOME/.local/share/anserin"
MARK_BEGIN="Anserin (added by install.sh) >>>"
MARK_END="<<< Anserin"

say()  { printf '\033[1;35m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }
ask()  { local reply; read -r -p "$1 [y/N] " reply </dev/tty || return 1; [[ "$reply" =~ ^[Yy]$ ]]; }

[[ $EUID -ne 0 ]] || die "Run this as your normal user, not root."

INSTALL_DIR="$DEFAULT_DIR"
HYPR_CONFIG=""
HYPR_BACKUP=""
[[ -r "$STATE_DIR/install-dir.env" ]] && source "$STATE_DIR/install-dir.env"
[[ -r "$STATE_DIR/install.env" ]] && source "$STATE_DIR/install.env"

# Only ever delete the copy install.sh made: a folder named anserin that holds Anserin's own command.
remove_dir=""
if [[ -x "$INSTALL_DIR/bin/anserin" && "$(basename "$INSTALL_DIR")" == anserin ]]; then
    remove_dir="$INSTALL_DIR"
elif [[ -e "$INSTALL_DIR" ]]; then
    warn "$INSTALL_DIR does not look like an Anserin install; it will be left alone."
fi
if [[ -n "$remove_dir" && -d "$remove_dir/.git" ]] && ! git -C "$remove_dir" diff --quiet HEAD -- 2>/dev/null; then
    die "$remove_dir has changes of your own (a development copy?). Nothing was removed."
fi

echo "This removes Anserin completely:"
[[ -n "$remove_dir" ]] && echo "  - the shell:            $remove_dir"
for name in anserin anserind; do
    [[ -L "$BIN_DIR/$name" ]] && echo "  - the command:          $BIN_DIR/$name"
done
for dir in "$CONFIG_DIR" "$STATE_DIR" "$CACHE_DIR" "$RUN_DIR"; do
    [[ -e "$dir" ]] && echo "  - settings/data:        $dir"
done
[[ -n "$HYPR_CONFIG" && -f "$HYPR_CONFIG" ]] && grep -qF "$MARK_BEGIN" "$HYPR_CONFIG" \
    && echo "  - the Anserin lines in: $HYPR_CONFIG"
echo "Your installed packages, wallpapers and other files stay."
ask "Remove Anserin now?" || { say "Nothing was removed."; exit 0; }

# Stop the shell first (only its own processes; Hyprland and your windows stay).
if [[ -n "$remove_dir" && -x "$remove_dir/bin/anserin" ]]; then
    "$remove_dir/bin/anserin" -end >/dev/null 2>&1 || true
fi

# The Hyprland config: take out only the marked block, so changes made since installing are kept.
if [[ -n "$HYPR_CONFIG" && -f "$HYPR_CONFIG" ]] && grep -qF "$MARK_BEGIN" "$HYPR_CONFIG"; then
    tmp="$(mktemp "$HYPR_CONFIG.XXXXXX")"
    # (the blank line install.sh put before the block goes with it)
    awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
        index($0, b) { skip = 1; held = 0; next }
        skip { if (index($0, e)) skip = 0; next }
        { if (held) print ""; held = 0
          if ($0 == "") { held = 1; next }
          print }
        END { if (held) print "" }
    ' "$HYPR_CONFIG" > "$tmp"
    cat "$tmp" > "$HYPR_CONFIG"
    rm -f "$tmp"
    say "Removed Anserin's lines from $HYPR_CONFIG"
    [[ -n "$HYPR_BACKUP" && -f "$HYPR_BACKUP" ]] && say "The copy from before installing is still at $HYPR_BACKUP"
fi

for name in anserin anserind; do
    [[ -L "$BIN_DIR/$name" ]] && rm -f "$BIN_DIR/$name"
done
for dir in "$CONFIG_DIR" "$CACHE_DIR" "$RUN_DIR" "$STATE_DIR"; do
    [[ -e "$dir" ]] && rm -rf -- "$dir"
done
[[ -n "$remove_dir" ]] && rm -rf -- "$remove_dir"

say "Anserin is removed. Log out and back in to Hyprland to finish."
