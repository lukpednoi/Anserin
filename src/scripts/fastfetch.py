#!/usr/bin/env python3
"""Run anserin's Fastfetch layout with the selected or random logo."""
import fcntl
import json
import math
import os
from pathlib import Path
import random
import re
import shlex
import shutil
import struct
import subprocess
import sys
import termios
import unicodedata

ROOT = Path(__file__).resolve().parents[2]
DEFAULTS = dict(mode='ascii', ascii='berserk.txt', pic='Mark.png', random=True, randomMode='ascii',
                auto=True, hideLogo=False)
FOLDERS = dict(ascii='ascii', pic='pngs')
EXTENSIONS = dict(ascii={'.txt'}, pic={'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp', '.avif'})


def normalize(settings):
    if not isinstance(settings, dict):
        settings = {}
    result = DEFAULTS | settings
    for key, values in dict(mode=('default', 'ascii', 'pic'), randomMode=('ascii', 'pic', 'both')).items():
        if result[key] not in values:
            result[key] = DEFAULTS[key]
    result['random'] = result['random'] is True
    result['auto'] = result['auto'] is True
    result['hideLogo'] = result['hideLogo'] is True
    return result


def sync(directory):
    directory.mkdir(parents=True, exist_ok=True)
    marker = directory / '.assets-imported'
    if not marker.exists():
        shutil.copytree(ROOT / 'config/fastfetch', directory, dirs_exist_ok=True)
        marker.touch()
    for folder in FOLDERS.values():
        (directory / folder).mkdir(exist_ok=True)
    source = ROOT / 'config/fastfetch/config.jsonc'
    target = directory / 'config.jsonc'
    if not target.exists() or target.read_bytes() != source.read_bytes():
        shutil.copy2(source, target)


def files(directory, kind):
    folder = directory / FOLDERS[kind]
    return sorted((p for p in folder.iterdir()
                   if p.is_file() and p.suffix.lower() in EXTENSIONS[kind]
                   and p.resolve().parent == folder.resolve()), key=lambda p: p.name.casefold())


def probe(args, directory):
    result = subprocess.run(['fastfetch', '--config', str(directory / 'config.jsonc')] + args +
                            ['--pipe', 'true'], capture_output=True, text=True, check=True, timeout=10,
                            env={**os.environ, 'XDG_CACHE_HOME': str(Path.home() / '.cache/anserin')})
    return re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', result.stdout.removesuffix('\n'))


def resize_ascii(text, height):
    lines = text.splitlines()
    braille = all(c == ' ' or '\u2800' <= c <= '\u28ff' for line in lines for c in line)
    if not lines or (len(lines) <= height and not braille):
        return text
    width = max(map(len, lines))
    if not width:
        return '\n' * (height - 1)
    columns = max(1, round(width * height / len(lines)))
    if braille:
        from PIL import Image
        # Resize Braille dots together so strokes survive between character cells.
        dots = ((0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (0, 3), (1, 3))
        image = Image.new('L', (width * 2, len(lines) * 4))
        for y, line in enumerate(lines):
            for x, char in enumerate(line):
                bits = ord(char) - 0x2800 if char != ' ' else 0
                for bit, (dx, dy) in enumerate(dots):
                    if bits & (1 << bit):
                        image.putpixel((x * 2 + dx, y * 4 + dy), 255)
        bbox = image.getbbox()
        if bbox:
            image = image.crop((0, bbox[1], image.width, bbox[3]))
        limit = max(1, height - 1) * 4
        columns = width
        if image.height > limit:
            columns = max(1, round(width * limit / image.height))
            image = image.resize((columns * 2, limit), Image.Resampling.BOX)
        bbox = image.getbbox()
        if bbox:
            image = image.crop((0, bbox[1], image.width, bbox[3]))
        canvas = Image.new('L', (columns * 2, height * 4))
        canvas.paste(image, (0, (canvas.height - image.height) // 2))
        return '\n'.join(''.join(chr(0x2800 + sum(1 << bit for bit, (dx, dy) in enumerate(dots)
                            if canvas.getpixel((x * 2 + dx, y * 4 + dy)) >= 128))
                            for x in range(columns)) for y in range(height))
    return '\n'.join(''.join(lines[min(len(lines) - 1, int((y + 0.5) * len(lines) / height))]
                            .ljust(width)[min(width - 1, int((x + 0.5) * width / columns))]
                            for x in range(columns)) for y in range(height))


def fit_logo(args, directory):
    lines = probe(['--logo', 'none'], directory).splitlines()
    top = next(i for i, line in enumerate(lines) if line.startswith('┌'))
    bottom = max(i for i, line in enumerate(lines) if line.startswith('└'))
    height = bottom - top + 1
    if args[1] == 'kitty' and sys.stdout.isatty():
        from PIL import Image
        source = Path(shlex.split(args[3])[0])
        # shortcut: use 8x16 cells when no pixel metrics are reported; prefer real terminal metrics.
        cell_width, cell_height = 8, 16
        try:
            rows, cols, xpixel, ypixel = struct.unpack('HHHH', fcntl.ioctl(
                sys.stdout.fileno(), termios.TIOCGWINSZ, bytes(8)))
            if rows and cols and xpixel and ypixel:
                cell_width, cell_height = xpixel / cols, ypixel / rows
        except (OSError, ValueError):
            pass
        with Image.open(source) as image:
            width, pixels_high = image.size
            scale = min(28 * cell_width / width, (height - 1) * cell_height / pixels_high)
            size = (max(1, round(width * scale)), max(1, round(pixels_high * scale)))
            # Border strokes sit halfway down their cells; center within their visible span.
            canvas = Image.new('RGBA', (size[0], round(height * cell_height)))
            canvas.alpha_composite(image.convert('RGBA').resize(size, Image.Resampling.LANCZOS),
                                   (0, (canvas.height - size[1]) // 2))
        cache = Path.home() / '.cache/anserin/fastfetch/centered'
        cache.mkdir(parents=True, exist_ok=True)
        target = cache / (source.name + '.png')
        temporary = cache / f'.{os.getpid()}.tmp'
        canvas.save(temporary, format='PNG')
        temporary.replace(target)
        return ['--logo-type', 'kitty', '--logo', shlex.quote(str(target)),
                '--logo-height', str(height), '--logo-padding-top', str(top)]
    if args[1] == 'kitty':
        args = ['--logo-type', 'builtin', '--logo', '']
    text = probe(args + ['--structure', 'break', '--logo-padding-right', '0', '--logo-padding-top', '0'], directory)
    art = text.splitlines()
    ink = [i for i, line in enumerate(art) if line.strip(' \t\u2800')]
    trimmed = '\n'.join(art[ink[0]:ink[-1] + 1]) if ink else text
    fitted = resize_ascii(trimmed, height)
    if fitted != text:
        args = ['--logo-type', 'data', '--logo', '$1' + fitted.replace('$', '$$')]
    return args + ['--logo-padding-top', str(top + (height - len(fitted.splitlines())) // 2)]


def hidden_logo(args, directory):
    if args[1] == 'kitty' and sys.stdout.isatty():
        from PIL import Image
        source = shlex.split(args[args.index('--logo') + 1])[0]
        with Image.open(source) as image:
            width, height = image.size
        divisor = math.gcd(width, height)
        cache = Path.home() / '.cache/anserin/fastfetch/hidden'
        cache.mkdir(parents=True, exist_ok=True)
        target = cache / f'{width}x{height}.png'
        if not target.exists():
            temporary = target.with_name(f'.{target.stem}-{os.getpid()}.tmp')
            # A transparent picture with the same aspect ratio reserves the original space.
            Image.new('RGBA', (width // divisor, height // divisor)).save(temporary, format='PNG')
            temporary.replace(target)
        return ['--logo-type', 'kitty', '--logo', shlex.quote(str(target))] + args[4:]
    text = probe(args + ['--structure', 'break', '--logo-padding-right', '0', '--logo-padding-top', '0'], directory)
    def blank(character):
        if character == '\n':
            return character
        return ' ' * (0 if unicodedata.combining(character) or unicodedata.category(character) == 'Cf'
                      else 2 if unicodedata.east_asian_width(character) in ('W', 'F') else 1)
    return ['--logo-type', 'data-raw', '--logo', ''.join(map(blank, text))] + args[4:]


def logo_args(settings, directory):
    settings = normalize(settings)
    if settings['random']:
        kinds = ('ascii', 'pic') if settings['randomMode'] == 'both' else (settings['randomMode'],)
        pool = [(kind, p) for kind in kinds for p in files(directory, kind)]
        kind, selected = random.choice(pool) if pool else ('default', None)
    else:
        kind = settings['mode']
        choices = files(directory, kind) if kind in FOLDERS else []
        selected = next((p for p in choices if p.name == settings[kind]), choices[0] if choices else None)
    if selected is None:
        args = ['--logo-type', 'builtin', '--logo', '']
    else:
        # Fastfetch expands logo paths with wordexp, even when passed as argv.
        source = shlex.quote(str(selected))
        args = ['--logo-type', 'kitty' if kind == 'pic' else 'file', '--logo', source]
    args = fit_logo(args, directory)
    return hidden_logo(args, directory) if settings['hideLogo'] else args


def main():
    directory = Path.home() / '.config/anserin/fastfetch'
    if sys.argv[1:] == ['--sync']:
        sync(directory)
        print('Fastfetch assets ready: ' + str(directory))
        return 0
    settings_path = Path.home() / '.config/anserin/settings.json'
    data = json.loads(settings_path.read_text()) if settings_path.exists() else {}
    settings = normalize(data.get('fastfetch', {}) if isinstance(data, dict) else {})
    arguments = sys.argv[1:]
    if arguments == ['--auto']:
        if not settings['auto']:
            return 0
        arguments = []
    sync(directory)
    command = ['fastfetch', '--config', str(directory / 'config.jsonc')]
    return subprocess.run(command + logo_args(settings, directory) + arguments,
                          env={**os.environ, 'XDG_CACHE_HOME': str(Path.home() / '.cache/anserin')}).returncode


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, TypeError, subprocess.SubprocessError) as error:
        print(f'Fastfetch: {error}', file=sys.stderr)
        sys.exit(1)
