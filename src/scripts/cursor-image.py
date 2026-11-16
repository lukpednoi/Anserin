#!/usr/bin/env python3
"""Export the pointer of the active XCursor theme as a PNG, for a cursor drawn by the shell (inf desktop pan).

Usage: cursor-image.py OUT_DIR PIXELS
Prints JSON {"path", "size", "hotX", "hotY"}: the image closest to PIXELS (at least it when possible),
with the hotspot in that image's pixels. The PNG is rewritten only when the theme or size changes.
"""
import json
import os
from pathlib import Path
import struct
import sys
import zlib

IMAGE_TYPE = 0xFFFD0002
SEARCH = [Path.home() / '.icons', Path.home() / '.local/share/icons', Path('/usr/share/icons')]


def inherits(theme):
    for base in SEARCH:
        index = base / theme / 'index.theme'
        if index.is_file():
            for line in index.read_text(errors='replace').splitlines():
                if line.strip().lower().startswith('inherits='):
                    return [t.strip() for t in line.split('=', 1)[1].split(',') if t.strip()]
    return []


def find_cursor(theme, seen=None):
    seen = seen or set()
    if theme in seen:
        return None
    seen.add(theme)
    for base in SEARCH:
        for name in ('left_ptr', 'default', 'arrow'):
            path = base / theme / 'cursors' / name
            if path.is_file():
                return path
    for parent in inherits(theme):
        found = find_cursor(parent, seen)
        if found:
            return found
    return None


def images(data):
    magic, _, _, count = struct.unpack('<4sIII', data[:16])
    if magic != b'Xcur':
        raise ValueError('Not an XCursor file')
    for i in range(count):
        kind, _, pos = struct.unpack('<III', data[16 + 12 * i:28 + 12 * i])
        if kind == IMAGE_TYPE:
            _, _, _, _, width, height, hot_x, hot_y, _ = struct.unpack('<IIIIIIIII', data[pos:pos + 36])
            yield width, height, hot_x, hot_y, data[pos + 36:pos + 36 + width * height * 4]


def png(width, height, argb):
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            b, g, r, a = argb[(y * width + x) * 4:(y * width + x) * 4 + 4]
            # XCursor pixels are premultiplied; PNG is not
            if a:
                r, g, b = (min(255, c * 255 // a) for c in (r, g, b))
            rows += bytes((r, g, b, a))
    chunk = lambda kind, body: struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(bytes(rows), 9)) + chunk(b'IEND', b''))


def main():
    out_dir, pixels = Path(sys.argv[1]), int(sys.argv[2])
    source = find_cursor(os.environ.get('XCURSOR_THEME') or 'default') or find_cursor('Adwaita')
    if not source:
        raise SystemExit('No cursor theme found')
    found = list(images(source.read_bytes()))
    larger = [i for i in found if i[0] >= pixels]
    width, height, hot_x, hot_y, argb = min(larger, key=lambda i: i[0]) if larger else max(found, key=lambda i: i[0])
    out_dir.mkdir(parents=True, exist_ok=True)
    target = out_dir / f'pointer-{width}.png'
    content = png(width, height, argb)
    if not target.exists() or target.read_bytes() != content:
        temporary = target.with_suffix('.tmp')
        temporary.write_bytes(content)
        temporary.replace(target)
    print(json.dumps({'path': str(target), 'size': width, 'hotX': hot_x, 'hotY': hot_y}))


if __name__ == '__main__':
    main()
