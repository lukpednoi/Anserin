#!/usr/bin/env bash
# Anserin installer.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/lukpednoi/Anserin/main/install/install.sh)
#   or, from a clone:  bash install/install.sh
#
# What it does, in order (it asks before the steps that change your system):
#   1. installs the packages Anserin needs (Arch and Arch-based distros; elsewhere it only checks them)
#   2. puts Anserin in ~/.local/share/anserin and the `anserin` command in ~/.local/bin
#   3. backs up your Hyprland config, then adds a small marked block that starts Anserin at login
# Uninstall with `bash ~/.local/share/anserin/install/uninstall.sh`.
set -euo pipefail

REPO_URL="${ANSERIN_REPO:-https://github.com/lukpednoi/Anserin.git}"
INSTALL_DIR="${ANSERIN_HOME:-$HOME/.local/share/anserin}"
BIN_DIR="$HOME/.local/bin"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/anserin"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/anserin"
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
MARK_BEGIN="Anserin (added by install.sh) >>>"
MARK_END="<<< Anserin"

# Everything Anserin calls, by Arch package name.
PACKAGES=(
    hyprland quickshell matugen
    kitty cava fastfetch nautilus
    pipewire wireplumber pipewire-pulse pipewire-alsa libpulse pamixer pavucontrol alsa-utils playerctl
    networkmanager iw bluez bluez-utils power-profiles-daemon brightnessctl ddcutil acpi lm_sensors
    wl-clipboard cliphist grim slurp satty wf-recorder gpu-screen-recorder wmctrl zbar
    qt6-base qt6-wayland qt6-multimedia qt6-5compat qt6-websockets qt6-shadertools
    qt5-wayland qt5-quickcontrols qt5-quickcontrols2 qt5-graphicaleffects qt5ct qt6ct
    xdg-desktop-portal-gtk adw-gtk-theme adwaita-fonts
    python python-gobject python-psutil python-pillow python-jeepney python-websockets
    jq socat inotify-tools fd ripgrep bc file psmisc wget unzip git imagemagick ffmpeg libnotify
    base-devel cmake pkgconf libsndfile wayland
)
# Optional, from the AUR: only installed when an AUR helper (yay/paru) is already there.
AUR_PACKAGES=(wl-gammarelay-rs)
# Commands checked on distros where the packages cannot be installed for you.
COMMANDS=(Hyprland hyprctl quickshell matugen kitty jq socat python3 git grim slurp wl-copy playerctl
          pamixer nmcli cmake c++ pkg-config magick ffmpeg)

say()  { printf '\033[1;35m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }
ask()  { local reply; read -r -p "$1 [y/N] " reply </dev/tty || return 1; [[ "$reply" =~ ^[Yy]$ ]]; }

[[ $EUID -ne 0 ]] || die "Run this as your normal user, not root. It asks for sudo itself when it needs it."

# ---------- 1. packages ----------
distro_family() {
    local id="" like=""
    if [[ -r /etc/os-release ]]; then
        id="$(. /etc/os-release; printf '%s' "${ID:-}")"
        like="$(. /etc/os-release; printf '%s' "${ID_LIKE:-}")"
    fi
    if [[ "$id" == arch || " $like " == *" arch "* ]] && command -v pacman >/dev/null; then
        echo arch
    else
        echo other
    fi
}

install_packages() {
    local missing=() pkg
    for pkg in "${PACKAGES[@]}"; do
        pacman -Qq "$pkg" >/dev/null 2>&1 || pacman -Qqg "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done
    if ((${#missing[@]})); then
        say "Packages to install: ${missing[*]}"
        ask "Install them with pacman (needs sudo)?" || die "Stopped. Nothing was changed."
        sudo pacman -S --needed "${missing[@]}" </dev/tty
    else
        say "All required packages are already installed."
    fi
    local helper=""
    command -v paru >/dev/null && helper=paru
    command -v yay >/dev/null && helper=yay
    for pkg in "${AUR_PACKAGES[@]}"; do
        pacman -Qq "$pkg" >/dev/null 2>&1 && continue
        if [[ -n "$helper" ]] && ask "Install the optional $pkg (night light) from the AUR with $helper?"; then
            "$helper" -S --needed "$pkg" </dev/tty || warn "$pkg was not installed; the night light may not work."
        else
            warn "Skipping the optional $pkg (the night light may not work without it)."
        fi
    done
}

check_commands() {
    local missing=() cmd
    for cmd in "${COMMANDS[@]}"; do command -v "$cmd" >/dev/null || missing+=("$cmd"); done
    if ((${#missing[@]})); then
        warn "These commands are missing: ${missing[*]}"
        warn "This distro is not Arch-based, so install them with your package manager"
        warn "(the Arch package names are listed at the top of install/install.sh), then run this again."
        exit 1
    fi
    say "Not an Arch-based distro: packages were only checked, and everything needed was found."
}

check_hyprland() {
    local version
    version="$(Hyprland --version 2>/dev/null | sed -n 's/^Hyprland \([0-9][0-9.]*\).*/\1/p' | head -n 1)"
    [[ -n "$version" ]] || die "Hyprland was not found. Anserin runs on Hyprland only for now."
    if [[ "$(printf '%s\n0.56\n' "$version" | sort -V | head -n 1)" != "0.56" ]]; then
        die "Hyprland $version is too old. Anserin needs Hyprland 0.56 or newer (Lua config)."
    fi
    say "Hyprland $version found."
}

# ---------- 2. files ----------
place_files() {
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd || true)"
    if [[ -n "$here" && -x "$here/bin/anserin" && "$here" == "$INSTALL_DIR" ]]; then
        say "Using the copy already in $INSTALL_DIR."
    elif [[ -d "$INSTALL_DIR/.git" ]]; then
        say "Anserin is already in $INSTALL_DIR; updating it."
        git -C "$INSTALL_DIR" pull --ff-only
    elif [[ -e "$INSTALL_DIR" ]]; then
        die "$INSTALL_DIR already exists and is not an Anserin checkout. Move it away and run this again."
    else
        say "Downloading Anserin into $INSTALL_DIR"
        mkdir -p "$(dirname "$INSTALL_DIR")"
        git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
    fi

    mkdir -p "$BIN_DIR"
    local name
    for name in anserin anserind; do
        if [[ -e "$BIN_DIR/$name" && ! -L "$BIN_DIR/$name" ]]; then
            die "$BIN_DIR/$name exists and is not a link. Move it away and run this again."
        fi
        ln -sfn "$INSTALL_DIR/bin/$name" "$BIN_DIR/$name"
    done
    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) warn "$BIN_DIR is not in your PATH. Add it (for example in ~/.bashrc) to use the \`anserin\` command." ;;
    esac

    if [[ ! -s "$CONFIG_DIR/settings.json" ]]; then
        mkdir -p "$CONFIG_DIR"
        cp "$INSTALL_DIR/config/anserin/settings.json" "$CONFIG_DIR/settings.json"
        say "Default settings written to $CONFIG_DIR/settings.json"
    else
        say "Keeping your existing settings in $CONFIG_DIR."
    fi
}

# ---------- 3. Hyprland ----------
hook_hyprland() {
    local target="" backup block
    # Hyprland not started yet: begin from Hyprland's own default config, as Hyprland would make on its first start.
    if [[ ! -f "$HYPR_DIR/hyprland.lua" && ! -f "$HYPR_DIR/hyprland.conf" && -f /usr/share/hypr/hyprland.lua ]]; then
        mkdir -p "$HYPR_DIR"
        cp /usr/share/hypr/hyprland.lua "$HYPR_DIR/hyprland.lua"
        say "No Hyprland config yet: started one from Hyprland's default ($HYPR_DIR/hyprland.lua)."
    fi
    if [[ -f "$HYPR_DIR/hyprland.lua" ]]; then
        target="$HYPR_DIR/hyprland.lua"
        # The profile adds Anserin's terminal, tiling and Infinite Desktop settings; pcall keeps Hyprland
        # starting even before Anserin has written that profile for the first time.
        block="-- $MARK_BEGIN
pcall(dofile, \"$INSTALL_DIR/config/terminal/desktop-profile.lua\")
hl.on(\"hyprland.start\", function()
    hl.exec_cmd('mkdir -p \"\$XDG_RUNTIME_DIR/anserin\" && exec \"$INSTALL_DIR/bin/anserin\" login >>\"\$XDG_RUNTIME_DIR/anserin/fork.log\" 2>&1')
end)
-- $MARK_END"
    elif [[ -f "$HYPR_DIR/hyprland.conf" ]]; then
        target="$HYPR_DIR/hyprland.conf"
        block="# $MARK_BEGIN
exec-once = mkdir -p \"\$XDG_RUNTIME_DIR/anserin\" && exec \"$INSTALL_DIR/bin/anserin\" login >>\"\$XDG_RUNTIME_DIR/anserin/fork.log\" 2>&1
# $MARK_END"
        warn "You use hyprland.conf. Anserin will start, but its terminal groups, Scrollable Tiling and"
        warn "Infinite Desktop need a hyprland.lua config."
    else
        warn "No Hyprland config found in $HYPR_DIR. Start Anserin yourself with \`anserin -start\`."
        return 0
    fi

    if grep -qF "$MARK_BEGIN" "$target"; then
        say "Your Hyprland config already starts Anserin."
        return 0
    fi
    ask "Add a few lines to $target so Anserin starts at login? (a backup is made first)" || {
        warn "Skipped. Start Anserin yourself with \`anserin -start\`."
        return 0
    }
    backup="$target.anserin-backup-$(LC_ALL=C date +%Y%m%d-%H%M%S)"
    cp -p "$target" "$backup"
    printf '\n%s\n' "$block" >> "$target"
    mkdir -p "$STATE_DIR"
    printf 'HYPR_CONFIG=%q\nHYPR_BACKUP=%q\n' "$target" "$backup" > "$STATE_DIR/install.env"
    say "Added. Your previous config is saved as $backup"
}

main() {
    say "Installing Anserin"
    if [[ "$(distro_family)" == arch ]]; then
        install_packages
    else
        check_commands
    fi
    check_hyprland
    place_files
    hook_hyprland
    mkdir -p "$STATE_DIR"
    printf 'INSTALL_DIR=%q\n' "$INSTALL_DIR" > "$STATE_DIR/install-dir.env"
    echo
    say "Done. From a terminal inside Hyprland:"
    echo "     anserin -start    open Anserin"
    echo "     anserin -end      close it (Hyprland and your windows stay)"
    echo "     anserin -up       update it"
    echo "   It also starts by itself the next time you log in to Hyprland."
}

main "$@"
