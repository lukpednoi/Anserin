#!/usr/bin/env python3
"""Capture desktop layouts and restore them with an archive and rollback."""
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import uuid


def validate(layouts, allow_missing=False):
    if not isinstance(layouts, dict):
        raise ValueError("Invalid widget layouts")
    json.dumps(layouts, allow_nan=False)
    for name, rows in layouts.items():
        if not re.fullmatch(r"[A-Za-z0-9_-]+", name) or name.startswith(("lockscreen-", "dashboard-")):
            raise ValueError("Invalid desktop monitor name")
        if rows is None and allow_missing:
            continue
        if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
            raise ValueError("Invalid widget list for " + name)


def read_layouts(state):
    layouts = {}
    for path in sorted((state / "widgets").glob("*/layout.json")):
        if not path.parent.name.startswith(("lockscreen-", "dashboard-")):
            layouts[path.parent.name] = json.loads(path.read_text())
    validate(layouts)
    return layouts


def snapshot(state, cache):
    layouts = read_layouts(state)
    image = cache / "wallpaper/current_wallpaper.png"
    wallpaper = ""
    if image.is_file():
        target = state / "presets" / uuid.uuid4().hex / "wallpaper.png"
        target.parent.mkdir(parents=True)
        shutil.copy2(image, target)
        wallpaper = str(target)
    return {"widgets": layouts, "wallpaper": wallpaper}


def atomic_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as handle:
        temporary = Path(handle.name)
        try:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def apply(state, layouts):
    validate(layouts, allow_missing=True)
    widgets = state / "widgets"
    if not widgets.resolve().is_relative_to(state.resolve()):
        raise ValueError("Widget layouts must stay inside Anserin state")
    paths = {name: widgets / name / "layout.json" for name in layouts}
    for path in paths.values():
        if not path.resolve().is_relative_to(widgets.resolve()) or path.is_symlink():
            raise ValueError("Refusing a linked widget layout")
    original = {name: path.read_bytes() if path.exists() else None for name, path in paths.items()}
    previous = {name: json.loads(content) if content is not None else None for name, content in original.items()}
    validate(previous, allow_missing=True)
    archive = state / "_to_delete" / ("preset-widgets-" + uuid.uuid4().hex)
    for name, content in original.items():
        if content is not None:
            atomic_write(archive / "widgets" / name / "layout.json", content)
    changed = []
    try:
        for name, rows in layouts.items():
            path = paths[name]
            if rows is None:
                if path.exists():
                    target = archive / "removed" / name / "layout.json"
                    target.parent.mkdir(parents=True)
                    path.rename(target)
            else:
                atomic_write(path, (json.dumps(rows, ensure_ascii=False, indent=2) + "\n").encode())
            changed.append(name)
    except OSError:
        for name in reversed(changed):
            if original[name] is not None:
                atomic_write(paths[name], original[name])
            elif paths[name].exists():
                target = archive / "failed" / name / "layout.json"
                target.parent.mkdir(parents=True)
                paths[name].rename(target)
        raise
    return {"previous": previous}


if __name__ == "__main__":
    try:
        mode, state = sys.argv[1], Path(sys.argv[2])
        result = snapshot(state, Path(sys.argv[3])) if mode == "snapshot" else apply(state, json.loads(sys.argv[3])) if mode == "apply" else {"widgets": read_layouts(state)} if mode == "layouts" else None
        if result is None:
            raise ValueError("Unknown operation")
        print(json.dumps(result, allow_nan=False))
    except (OSError, ValueError, IndexError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
