#!/usr/bin/env python3
"""Render Mo's Kitty, Bash and Hyprland appearance without editing their entry files."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
# Pan / move / resize: 'anserin' ways are fixed; 'custom' uses the keys below (defaults as in the original repo).
INFINITE_DEFAULTS = dict(toggleShortcut='SUPER + CTRL', panMode='anserin', panKeys='SUPER + ALT',
                         navigateMode='anserin', navigateKeys='SUPER',
                         moveMode='anserin', moveKeys='SUPER + SHIFT', resizeMode='anserin', resizeKeys='SUPER + CTRL',
                         cellScale=100)
MODIFIERS = ('SUPER', 'CTRL', 'ALT', 'SHIFT')
ARROW_KINDS = ('navigateKeys', 'moveKeys', 'resizeKeys')
SCROLLABLE_DEFAULTS = dict(windowLayout='hyprland', appsScrollable=False)
DEFAULTS = dict(background='clear', blurSize=8, prompt='hex', border='white', workspace='horizontal',
                infiniteDesktop=INFINITE_DEFAULTS, scrollableTiling=SCROLLABLE_DEFAULTS)
CHOICES = dict(background=('default', 'blur', 'clear'), prompt=('default', 'hex'),
               border=('white', 'default', 'theme', 'none'), workspace=('vertical', 'horizontal'))


def toggle_shortcut(value):
    if not isinstance(value, str):
        raise ValueError('Use a shortcut such as WIN + CTRL or SUPER + F10')
    parts = [{'WIN': 'SUPER', 'CONTROL': 'CTRL'}.get(part.strip().upper(), part.strip().upper()) for part in value.split('+')]
    if parts == ['SUPER', 'CTRL'] or parts == ['CTRL', 'SUPER']:
        return 'SUPER + CTRL'
    if parts == ['SUPER', 'ALT'] or parts == ['ALT', 'SUPER']:
        return 'SUPER + ALT'
    if len(parts) < 2 or len(set(parts)) != len(parts) or any(p not in ('SUPER', 'ALT', 'CTRL', 'SHIFT') for p in parts[:-1]):
        raise ValueError('Start with SUPER, ALT, CTRL or SHIFT, then one key')
    if not re.fullmatch(r'[A-Z0-9]|F(?:[1-9]|1[0-9]|2[0-4])|SPACE|RETURN|TAB|HOME|END|INSERT|DELETE|PAGE_UP|PAGE_DOWN', parts[-1]):
        raise ValueError('Use a letter, digit, F1–F24, Space, Return or navigation key')
    return ' + '.join(parts)


def modifier_keys(value):
    """Modifiers only (held for a pan, or pressed with the arrows); a recorded arrow key is dropped."""
    if not isinstance(value, str):
        raise ValueError('Press modifier keys such as SUPER + SHIFT')
    parts = [{'WIN': 'SUPER', 'CONTROL': 'CTRL'}.get(p.strip().upper(), p.strip().upper()) for p in value.split('+') if p.strip()]
    if parts and parts[-1] in ('LEFT', 'RIGHT', 'UP', 'DOWN'):
        parts = parts[:-1]
    if not parts or len(set(parts)) != len(parts) or any(p not in MODIFIERS for p in parts):
        raise ValueError('Use only SUPER, CTRL, ALT and SHIFT')
    return ' + '.join(m for m in MODIFIERS if m in parts)


def check_infinite_keys(kind, value, current, bindings):
    """Validate the keys of one inf desktop action against the other actions and Hyprland's bindings."""
    if kind not in ('panKeys',) + ARROW_KINDS:
        raise ValueError('Unknown inf desktop action')
    value = modifier_keys(value)
    settings = normalize_infinite(current)
    settings[kind] = value
    names = dict(panKeys='Pan', navigateKeys='Go to window', moveKeys='Move window', resizeKeys='Resize')
    # Anserin's Go to window is SUPER + arrows; custom actions use their own keys
    used = {k: settings[k] if settings[k.replace('Keys', 'Mode')] == 'custom' else 'SUPER'
            for k in ARROW_KINDS if k == 'navigateKeys' or settings[k.replace('Keys', 'Mode')] == 'custom'}
    if kind in ARROW_KINDS:
        for other, keys in used.items():
            if other != kind and keys == value:
                raise ValueError(f'{names[other]} already uses {value} + arrows')
        mask = sum({'SUPER': 64, 'ALT': 8, 'CTRL': 4, 'SHIFT': 1}[p] for p in value.split(' + '))
        for binding in bindings:
            if binding.get('submap', '') or binding.get('description', '').startswith('Mo inf desktop:'):
                continue
            # SUPER + arrows is Hyprland's own focus, which inf desktop has always replaced
            if value == 'SUPER':
                continue
            if binding.get('modmask') == mask and binding.get('key', '').lower() in ('left', 'right', 'up', 'down'):
                raise ValueError('Keys conflict with an existing Hyprland binding: ' + value + ' + arrows')
    else:
        toggle = settings['toggleShortcut']
        if toggle in ('SUPER + CTRL', 'SUPER + ALT') and value == toggle:
            raise ValueError('The inf desktop toggle already uses ' + value)
    return value


def normalize_infinite(infinite):
    if not isinstance(infinite, dict):
        infinite = {}
    result = dict(toggleShortcut=toggle_shortcut(infinite.get('toggleShortcut', 'SUPER + CTRL')))
    for mode in ('panMode', 'navigateMode', 'moveMode', 'resizeMode'):
        result[mode] = infinite.get(mode) if infinite.get(mode) in ('anserin', 'custom') else 'anserin'
    for keys in ('panKeys',) + ARROW_KINDS:
        try:
            result[keys] = modifier_keys(infinite.get(keys, INFINITE_DEFAULTS[keys]))
        except ValueError:
            result[keys] = INFINITE_DEFAULTS[keys]
    scale = infinite.get('cellScale', 100)
    result['cellScale'] = max(50, min(150, int(scale))) if isinstance(scale, (int, float)) and not isinstance(scale, bool) else 100
    return result


def check_toggle_shortcut(value, bindings):
    value = toggle_shortcut(value)
    if value == 'SUPER + CTRL':
        candidates = [(64, 'control_l'), (64, 'control_r'), (4, 'super_l'), (4, 'super_r'),
                      (68, 'control_l'), (68, 'control_r'), (68, 'super_l'), (68, 'super_r')]
    elif value == 'SUPER + ALT':
        candidates = [(64, 'alt_l'), (64, 'alt_r'), (8, 'super_l'), (8, 'super_r')]
    else:
        parts = value.split(' + ')
        candidates = [(sum({'SUPER': 64, 'ALT': 8, 'CTRL': 4, 'SHIFT': 1}[p] for p in parts[:-1]), parts[-1].lower())]
    reserved = {(64, key) for key in ('left', 'right', 'up', 'down', 'mouse_up', 'mouse_down')}
    if any(candidate in reserved for candidate in candidates):
        raise ValueError('This shortcut is already used by inf desktop')
    for binding in bindings:
        if binding.get('submap', '') or binding.get('description', '').startswith('Mo inf desktop:'):
            continue
        if any(binding.get('modmask') == mask and binding.get('key', '').lower() == key for mask, key in candidates):
            raise ValueError('Shortcut conflicts with an existing Hyprland binding: ' + value)
    return value


def normalize(settings):
    if not isinstance(settings, dict):
        settings = {}
    result = {key: settings.get(key) if settings.get(key) in values else DEFAULTS[key]
              for key, values in CHOICES.items()}
    if settings.get('workspace') in ('up', 'down'):
        result['workspace'] = 'vertical'
    size = settings.get('blurSize', DEFAULTS['blurSize'])
    result['blurSize'] = max(1, min(20, size)) if type(size) is int else DEFAULTS['blurSize']
    result['infiniteDesktop'] = normalize_infinite(settings.get('infiniteDesktop', {}))
    scrollable = settings.get('scrollableTiling', {})
    if not isinstance(scrollable, dict):
        scrollable = {}
    # Window layout was called terminalMode before
    mode = scrollable.get('windowLayout', scrollable.get('terminalMode'))
    result['scrollableTiling'] = dict(
        windowLayout=mode if mode in ('hyprland', 'niri', 'hybrid') else 'hyprland',
        appsScrollable=scrollable.get('appsScrollable') is True)
    return result


def color(value, fallback):
    return value.lower() if isinstance(value, str) and re.fullmatch(r'#[0-9a-fA-F]{6}', value) else fallback


def luminance(channels):
    linear = [c / 255 / 12.92 if c / 255 <= .04045 else ((c / 255 + .055) / 1.055) ** 2.4 for c in channels]
    return sum(c * weight for c, weight in zip(linear, (.2126, .7152, .0722)))


def contrast(first, second):
    values = sorted((luminance(first), luminance(second)))
    return (values[1] + .05) / (values[0] + .05)


def render(settings, palette):
    settings = normalize(settings)
    if not isinstance(palette, dict):
        palette = {}
    accent = color(palette.get('accent'), '#cba6f7')
    foreground = color(palette.get('text'), '#cdd6f4')
    background = color(palette.get('base'), '#1e1e2e')
    channels = tuple(int(accent[i:i + 2], 16) for i in (1, 3, 5))
    base_channels = tuple(int(background[i:i + 2], 16) for i in (1, 3, 5))
    text_channels = tuple(int(foreground[i:i + 2], 16) for i in (1, 3, 5))
    shade_channels = [tuple(round(c * factor) for c in channels) for factor in (.22, .38, .55)]
    line_color = ';'.join(map(str, text_channels))
    # Keep the darkest segment distinct from Kitty's background.
    contrast_target = (255, 255, 255) if luminance(base_channels) < .18 else (0, 0, 0)
    for amount in range(0, 101, 5):
        shades = [tuple(round(c + (t - c) * amount / 100) for c, t in zip(shade, contrast_target)) for shade in shade_channels]
        if contrast(shades[0], base_channels) >= 3:
            break
    if min(contrast(text_channels, shade) for shade in shades) < 4.5:
        text_channels = max(((0, 0, 0), (255, 255, 255)), key=lambda text: min(contrast(text, shade) for shade in shades))
    shades = [';'.join(map(str, shade)) for shade in shades]
    prompt = f"_mo_style={settings['prompt']}\n"
    prompt += ''.join(f"_mo_bg{i}='{shade}'\n" for i, shade in enumerate(shades))
    prompt += f"_mo_line='{line_color}'\n"
    prompt += "_mo_fg='" + ';'.join(map(str, text_channels)) + "'\n"

    kitty = '# Generated by anserin; change these options in Settings > Terminal.\n'
    kitty += 'globinclude ../kitty/colors.conf\n'
    kitty += f"background_opacity {dict(default='1.0', blur='0.35', clear='0.0')[settings['background']]}\n"
    kitty += f"background_blur {settings['blurSize'] * 2 if settings['background'] == 'blur' else 0}\n"
    kitty += 'window_padding_width 12\n'
    kitty += 'cursor_shape beam\ncursor_trail 1\n'
    kitty += 'confirm_os_window_close 0\n'
    kitty += 'symbol_map U+E0B0-U+E0B3,U+F07B,U+F303 CaskaydiaCove Nerd Font Mono\n'
    kitty += f'shell bash --rcfile "{ROOT}/config/terminal/bashrc"\n'

    lua = '-- Generated by anserin; change these options in Settings > Terminal.\n'
    if settings['border'] == 'none':
        lua += 'hl.config({ general = { border_size = 0 } })\n'
    elif settings['border'] != 'default':
        border = '#ffffff' if settings['border'] == 'white' else accent
        lua += f'hl.config({{ general = {{ col = {{ active_border = "rgb({border[1:]})" }} }} }})\n'
    if settings['background'] != 'default':
        no_blur = 'true' if settings['background'] == 'clear' else 'false'
        lua += ('hl.window_rule({ name = "mo-terminal-blur", match = { class = "^(kitty)$" }, '
                f'no_blur = {no_blur}' + ' })\n')
        if settings['background'] == 'blur':
            # Kitty's background_blur does not set Hyprland's blur strength.
            lua += f'hl.config({{ decoration = {{ blur = {{ enabled = true, size = {settings["blurSize"]}, passes = 3 }} }} }})\n'
    # Leave the side unset so Hyprland reverses motion when navigating back.
    style = 'slidevert' if settings['workspace'] == 'vertical' else 'slide'
    lua += 'hl.curve("moWorkspace", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })\n'
    for leaf in ('workspaces', 'workspacesIn', 'workspacesOut'):
        lua += f'hl.animation({{ leaf = "{leaf}", enabled = true, speed = 4, bezier = "moWorkspace", style = "{style}" }})\n'
    infinite = settings['infiniteDesktop']
    module = json.dumps(str(ROOT / 'src/scripts/infinite-desktop-v2/desktop.lua'))
    layout_file = json.dumps(str(ROOT / 'src/scripts/infinite-desktop-v2/layout.lua'))
    state = json.dumps(str(Path.home() / '.local/state/anserin/infinite-desktop-v2.lua'))
    options = ''.join(f'{lua_key} = {json.dumps(infinite[key])}, ' for lua_key, key in (
        ('toggle_shortcut', 'toggleShortcut'), ('pan_mode', 'panMode'), ('pan_keys', 'panKeys'),
        ('navigate_mode', 'navigateMode'), ('navigate_keys', 'navigateKeys'), ('move_mode', 'moveMode'), ('move_keys', 'moveKeys'),
        ('resize_mode', 'resizeMode'), ('resize_keys', 'resizeKeys'), ('cell_scale', 'cellScale')))
    runtime = os.environ.get('XDG_RUNTIME_DIR')
    if runtime:
        options += f'cursor_file = {json.dumps(str(Path(runtime) / "anserin/inf-pan-cursor"))}, '
    lua += f'dofile({module})({{ {options}state_file = {state}, layout_file = {layout_file} }})\n'

    scrollable = settings['scrollableTiling']
    scroll_module = json.dumps(str(ROOT / 'src/scripts/scrollable-tiling.lua'))
    scroll_model = json.dumps(str(ROOT / 'src/scripts/scrollable-tiling-model.lua'))
    scroll_state = json.dumps(str(Path.home() / '.local/state/anserin/scrollable-tiling.lua'))
    lua += (f'dofile({scroll_module})({{ mode = {json.dumps(scrollable["windowLayout"])}, '
            f'apps = {str(scrollable["appsScrollable"]).lower()}, vertical = {str(settings["workspace"] == "horizontal").lower()}, '
            f'state_file = {scroll_state}, model_file = {scroll_model}, layout_file = {layout_file} }})\n')
    return {'kitty.conf': kitty, 'prompt.env': prompt, 'hyprland.lua': lua}


def write_profiles(directory, profiles):
    directory.mkdir(parents=True, exist_ok=True)
    changed = []
    for name, content in profiles.items():
        target = directory / name
        if target.exists() and target.read_text() == content:
            continue
        # Replace complete files so Bash never reads a half-written prompt palette.
        temporary = directory / ('.' + name + '.tmp')
        temporary.write_text(content)
        temporary.replace(target)
        changed.append(name)
    return changed


def hyprland_hook():
    return 'dofile(os.getenv("HOME") .. "/.config/anserin/terminal/hyprland.lua")'


def apply_desktop(directory, config):
    if not config.exists() or not os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
        return
    content = config.read_text()
    if hyprland_hook() not in content and '/config/terminal/desktop-profile.lua' not in content:
        return
    content = (directory / 'hyprland.lua').read_text()
    applied = directory / 'hyprland.applied.lua'
    if applied.exists() and applied.read_text() == content:
        return
    result = subprocess.run(['hyprctl', 'reload', 'config-only'], capture_output=True, text=True, timeout=10)
    if result.returncode or result.stdout.strip().lower() != 'ok':
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or 'Hyprland reload failed')
    errors = subprocess.run(['hyprctl', 'configerrors'], capture_output=True, text=True, timeout=10)
    if errors.returncode or errors.stdout.strip():
        raise RuntimeError(errors.stderr.strip() or errors.stdout.strip() or 'Cannot verify Hyprland configuration')
    loaded = subprocess.run(['hyprctl', 'eval', 'assert(AnserinScrollable, "Scrollable Tiling did not load")'],
                            capture_output=True, text=True, timeout=10)
    if loaded.returncode:
        raise RuntimeError(loaded.stderr.strip() or loaded.stdout.strip() or 'Scrollable Tiling did not load')
    # Record success only after reload; a failed request must remain retryable.
    applied.write_text(content)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('payload', nargs='?', help='JSON containing settings and the active theme palette')
    parser.add_argument('--check-shortcut', help='Validate a toggle shortcut against active Hyprland bindings')
    parser.add_argument('--check-keys', nargs=3, metavar=('ACTION', 'KEYS', 'CURRENT'),
                        help='Validate the keys of an inf desktop action (panKeys, navigateKeys, moveKeys, resizeKeys)')
    parser.add_argument('--apply', action='store_true', help='Reload an already connected Hyprland profile')
    args = parser.parse_args()
    if args.check_shortcut is not None:
        result = subprocess.run(['hyprctl', '-j', 'binds'], capture_output=True, text=True, check=True, timeout=5)
        print(check_toggle_shortcut(args.check_shortcut, json.loads(result.stdout)))
        return
    if args.check_keys is not None:
        kind, value, current = args.check_keys
        result = subprocess.run(['hyprctl', '-j', 'binds'], capture_output=True, text=True, check=True, timeout=5)
        print(check_infinite_keys(kind, value, json.loads(current), json.loads(result.stdout)))
        return
    if args.payload is None:
        parser.error('payload is required unless --check-shortcut is used')
    payload = json.loads(args.payload)
    if not isinstance(payload, dict):
        raise ValueError('Expected a JSON object')
    directory = Path.home() / '.config/anserin/terminal'
    changed = write_profiles(directory, render(payload.get('settings', {}), payload.get('palette', {})))
    if args.apply:
        apply_desktop(directory, Path.home() / '.config/hypr/hyprland.lua')
    print('Terminal appearance: updated ' + (', '.join(changed) or 'nothing'))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, TypeError, RuntimeError, subprocess.SubprocessError) as error:
        print(f'Terminal appearance: {error}', file=sys.stderr)
        sys.exit(1)
