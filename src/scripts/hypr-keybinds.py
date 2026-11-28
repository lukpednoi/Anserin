#!/usr/bin/env python3
"""Anserin's Hyprland shortcuts, made from the user's own binds.

Reads `hyprctl binds -j`, gives each Anserin shortcut its key (SUPER + K) when nothing of the user's uses it, else
SUPER + ALT + K, else skips it. Writes ~/.config/anserin/hyprland/keybinds.lua (loaded by
config/terminal/desktop-profile.lua) and ~/.local/state/anserin/keybinds.json (shown in Control Center > Welcome),
then reloads Hyprland only when the shortcuts changed. Our own binds carry the description prefix TAG, so they never
block themselves.
"""
import json
import os
from pathlib import Path
import subprocess
import sys

TAG = 'Anserin key: '
MODS = {'SHIFT': 1, 'CAPS': 2, 'CTRL': 4, 'CONTROL': 4, 'ALT': 8, 'MOD2': 16, 'MOD3': 32, 'SUPER': 64, 'MOD5': 128}
ANSERIN = str(Path(__file__).resolve().parent.parent.parent / 'bin' / 'anserin')

# (id, label, icon, preferred keys, fallback keys, anserin arguments). Left-panel pages (Music, Network) are left out:
# the panel hides at once when the pointer is not over it, so a key cannot keep it open.
SHORTCUTS = [
    ('launcher', 'Apps', '󰀻', 'SUPER + D', 'SUPER + ALT + D', ['msg', 'toggle', 'launcher']),
    ('clipboard', 'Clipboard', '󰅌', 'SUPER + V', 'SUPER + ALT + V', ['msg', 'toggle', 'clipboard']),
    ('control', 'Control Center', '󰒓', 'SUPER + H', 'SUPER + ALT + H', ['msg', 'toggle', 'guide']),
    ('wallpaper', 'Wallpapers', '󰸉', 'SUPER + W', 'SUPER + ALT + W', ['msg', 'toggle', 'wallpaper']),
    ('lock', 'Lock screen', '󰌾', 'SUPER + L', 'SUPER + ALT + L', ['lock']),
    ('screenshot', 'Screenshot', '󰹑', 'Print', 'SUPER + ALT + S', ['screenshot']),
]


def parse(keys):
    """'SUPER + ALT + D' -> (72, 'd')."""
    parts = [p.strip() for p in keys.split('+') if p.strip()]
    mask = 0
    for part in parts[:-1]:
        mask |= MODS[part.upper()]
    return mask, parts[-1].lower()


def taken_keys():
    out = subprocess.run(['hyprctl', 'binds', '-j'], capture_output=True, text=True, timeout=10, check=True).stdout
    taken = set()
    for bind in json.loads(out):
        if (bind.get('description') or '').startswith(TAG) or bind.get('submap'):
            continue
        taken.add((int(bind.get('modmask', 0)), str(bind.get('key', '')).lower()))
    return taken


def choose(taken):
    chosen = []
    for ident, label, icon, first, second, args in SHORTCUTS:
        keys = next((k for k in (first, second) if parse(k) not in taken), '')
        if keys:
            taken.add(parse(keys))
        chosen.append({'id': ident, 'label': label, 'icon': icon, 'keys': keys, 'wanted': first, 'args': args})
    return chosen


def lua(chosen):
    lines = ['-- Written by Anserin (src/scripts/hypr-keybinds.py) from your own binds; changes here are replaced.']
    for item in chosen:
        if not item['keys']:
            continue
        command = ' '.join("'" + a.replace("'", "'\\''") + "'" for a in [ANSERIN] + item['args'])
        lines.append('hl.bind(%s, hl.dsp.exec_cmd(%s), { description = %s })' % (
            json.dumps(item['keys']), json.dumps(command), json.dumps(TAG + item['label'])))
    return '\n'.join(lines) + '\n'


def write_if_changed(path, text):
    if path.exists() and path.read_text() == text:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + '.tmp')
    tmp.write_text(text)
    tmp.replace(path)
    return True


def main():
    if not os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
        return 0
    home = Path.home()
    # the same places the shell and desktop-profile.lua use
    config = home / '.config' / 'anserin' / 'hyprland' / 'keybinds.lua'
    state = Path(os.environ.get('QS_STATE_DIR') or home / '.local' / 'state' / 'anserin') / 'keybinds.json'
    chosen = choose(taken_keys())
    changed = write_if_changed(config, lua(chosen))
    write_if_changed(state, json.dumps([{k: v for k, v in c.items() if k != 'args'} for c in chosen], indent=1) + '\n')
    if changed:
        result = subprocess.run(['hyprctl', 'reload', 'config-only'], capture_output=True, text=True, timeout=10)
        if result.returncode:
            print('hypr-keybinds: Hyprland reload failed: ' + (result.stderr or result.stdout).strip(), file=sys.stderr)
            return 1
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, subprocess.SubprocessError, ValueError, KeyError) as error:
        print(f'hypr-keybinds: {error}', file=sys.stderr)
        sys.exit(1)
