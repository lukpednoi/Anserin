#!/usr/bin/env python3
"""Pick a local still image without changing wallpaper or building thumbnails."""
import random
import sys
from pathlib import Path


def candidates(directory, current):
    extensions = {'.jpg', '.jpeg', '.png', '.webp', '.bmp', '.avif'}
    root = Path(directory).expanduser()
    if not root.is_dir():
        raise ValueError('Wallpaper directory is unavailable')
    images = [p for p in root.glob('*') if p.is_file() and p.suffix.lower() in extensions]
    images += [p for folder in root.iterdir() if folder.is_dir()
               for p in folder.glob('*') if p.is_file() and p.suffix.lower() in extensions]
    others = [p for p in images if str(p.resolve()) != current]
    return others or images


if __name__ == '__main__':
    try:
        images = candidates(sys.argv[1], sys.argv[2])
        if not images:
            raise ValueError('No local still wallpapers found')
        print(random.choice(images).resolve())
    except (OSError, ValueError, IndexError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
