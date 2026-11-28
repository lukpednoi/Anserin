#!/usr/bin/env bash
# Gives a screen with no saved wallpaper one of Anserin's own (a new install, or one made before they shipped).
#   default-wallpaper.sh <wallpaper folder> <bundled folder>
# When the wallpaper folder has no pictures or videos yet (itself, Images/ or Videos/), the bundled ones are
# copied into its Images/ so they show up in Select Wallpaper; files already there are never replaced.
# Prints the picture to use.
set -u
dir="${1:?wallpaper folder}"
bundle="${2:?bundled folder}"
first="anserin-teal-peaks.jpg"

has_media() {
    find "$dir" "$dir/Images" "$dir/Videos" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
        -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.webm' \) \
        -print -quit 2>/dev/null | grep -q .
}

if ! has_media && mkdir -p "$dir/Images" 2>/dev/null; then
    cp -n "$bundle"/anserin-*.jpg "$dir/Images/" 2>/dev/null
fi
if [ -f "$dir/Images/$first" ]; then
    printf '%s\n' "$dir/Images/$first"
elif [ -f "$bundle/$first" ]; then
    printf '%s\n' "$bundle/$first"
fi
