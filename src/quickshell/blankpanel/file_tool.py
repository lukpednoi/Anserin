#!/usr/bin/env python3
"""File operations for the left panel's File page (FilePage.qml). Prints one JSON object per call.

  apps PATH                         the applications for PATH's type: {"apps": [{id, name, icon, default}]}
  open-with APP_ID PATH             open PATH with the application APP_ID (a .desktop id)
  paste copy|move ask|replace|skip DEST PATH...
                                    copy or move PATHs into DEST. "ask": if any name is already in DEST, do nothing and
                                    return {"conflicts": [names]}; "replace": the existing one goes to the Trash first;
                                    "skip": leave those out. Never deletes anything for good.
  rename PATH NEW_NAME              rename in place; refuses a name that is taken
  new-folder DIR                    make "New Folder" (or "New Folder 2", ...) in DIR: {"name": ...}
  new-file DIR                      make an empty "New File.txt" (or "New File 2.txt", ...) in DIR: {"name": ...}
  trash PATH...                     move to the Trash (the same one Dolphin uses)
  remove PATH...                    delete for good items shown in the Trash (only there: anything else is refused)
  restore ask|replace|skip PATH...  put items shown in the Trash back where they were deleted from (making the folder
                                    again if it is gone); a name already there: "ask" returns {"conflicts": [names]},
                                    "replace" sends the one there to the Trash first, "skip" leaves it in the Trash
  empty-trash                       delete everything in the Trash for good
  extract ARCHIVE                   unpack beside the archive (bsdtar, unrar for what it cannot read): one folder or
                                    file at the top comes out as it is, anything else goes into a folder named after
                                    the archive; a name already there gets " 2", " 3", ...; nothing is overwritten:
                                    {"name": what was made}
  devices                           the partition / is on, and the plugged-in drives: {"devices": [...]}
  mount DEVICE                      mount a plugged-in drive (udisks, as Dolphin does): {"mount": path}
  eject DEVICE                      unmount it and power its drive off, ready to unplug
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio  # noqa: E402


def out(obj, code=0):
    print(json.dumps(obj))
    sys.exit(code)


def trash(path):
    Gio.File.new_for_path(path).trash(None)


# ---------- the Trash (the one Dolphin uses), handled as the freedesktop spec lays it out: files/NAME and
# info/NAME.trashinfo (where it came from), plus KDE's directorysizes cache line for a folder. Done on the files
# themselves: GIO's trash:/// view is a cached copy that can miss items just trashed.
TRASH = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"), "Trash")
TRASH_FILES = os.path.join(TRASH, "files")


def trash_parts(path):
    """the path's parts below the Trash's files folder, or None for a path outside it"""
    rel = os.path.relpath(os.path.abspath(path), TRASH_FILES)
    if rel in (".", "..") or rel.startswith(".." + os.sep) or os.path.isabs(rel):
        return None
    return rel.split(os.sep)


def info_file(name):
    return os.path.join(TRASH, "info", name + ".trashinfo")


def orig_path(name):
    with open(info_file(name), encoding="utf-8") as f:
        for line in f:
            if line.startswith("Path="):
                p = urllib.parse.unquote(line[5:].strip())
                return p if os.path.isabs(p) else os.path.join(os.path.dirname(TRASH), p)
    return ""


def forget(name):
    """drop a top-level item's .trashinfo and its directorysizes line"""
    if os.path.exists(info_file(name)):
        os.remove(info_file(name))
    sizes = os.path.join(TRASH, "directorysizes")
    if os.path.exists(sizes):
        with open(sizes, encoding="utf-8") as f:
            lines = f.readlines()
        keep = [l for l in lines if urllib.parse.unquote(l.rstrip("\n").split(" ", 2)[-1]) != name]
        if len(keep) != len(lines):
            with open(sizes, "w", encoding="utf-8") as f:
                f.writelines(keep)


def delete_now(path):
    if os.path.isdir(path) and not os.path.islink(path):
        shutil.rmtree(path)
    elif os.path.lexists(path):
        os.remove(path)


def remove(paths):
    errors = []
    for p in paths:
        parts = trash_parts(p)
        try:
            if parts is None:
                raise ValueError("not in the Trash")
            delete_now(p)
            if len(parts) == 1:
                forget(parts[0])
        except Exception as e:
            errors.append(os.path.basename(p) + ": " + str(e))
    out({"done": len(paths) - len(errors), "errors": errors})


def restore(policy, paths):
    pairs = []
    for p in paths:
        parts = trash_parts(p)
        if parts is None or not os.path.lexists(p):
            continue
        try:
            orig = orig_path(parts[0])
        except OSError:
            orig = ""
        if not orig:
            out({"error": "Where “" + parts[0] + "” came from is not known"}, 1)
        pairs.append((p, os.path.join(orig, *parts[1:]), parts))
    conflicts = [os.path.basename(t) for s, t, _ in pairs if os.path.lexists(t)]
    if policy == "ask" and conflicts:
        out({"conflicts": conflicts})
    done, errors = 0, []
    for src, target, parts in pairs:
        try:
            if os.path.lexists(target):
                if policy == "skip":
                    continue
                trash(target)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            shutil.move(src, target)
            if len(parts) == 1:
                forget(parts[0])
            done += 1
        except Exception as e:
            errors.append(os.path.basename(src) + ": " + str(e))
    out({"done": done, "errors": errors})


def empty_trash():
    errors = []
    for name in os.listdir(TRASH_FILES) if os.path.isdir(TRASH_FILES) else []:
        try:
            delete_now(os.path.join(TRASH_FILES, name))
            forget(name)
        except Exception as e:
            errors.append(name + ": " + str(e))
    # .trashinfo files whose item is already gone
    info_dir = os.path.join(TRASH, "info")
    for name in os.listdir(info_dir) if os.path.isdir(info_dir) else []:
        if name.endswith(".trashinfo") and not os.path.lexists(os.path.join(TRASH_FILES, name[:-10])):
            os.remove(os.path.join(info_dir, name))
    out({"errors": errors})


# ---------- archives ----------
ARCHIVE_ENDINGS = (".tar.gz", ".tar.xz", ".tar.bz2", ".tar.zst", ".tar.lz4", ".tar", ".tgz", ".txz", ".tbz", ".tbz2",
                   ".tzst", ".zip", ".7z", ".rar", ".iso", ".cpio", ".xpi", ".jar", ".apk")


def archive_stem(name):
    low = name.lower()
    for end in ARCHIVE_ENDINGS:
        if low.endswith(end) and len(name) > len(end):
            return name[:-len(end)]
    return os.path.splitext(name)[0] or name


def free_name(folder, name):
    """name, or "name 2", "name 3", ... (before the extension for a file), whichever is not taken in folder"""
    if not os.path.lexists(os.path.join(folder, name)):
        return name
    base, ext = os.path.splitext(name)
    n = 2
    while os.path.lexists(os.path.join(folder, f"{base} {n}{ext}")):
        n += 1
    return f"{base} {n}{ext}"


def extract(archive):
    archive = os.path.abspath(archive)
    if not os.path.isfile(archive):
        out({"error": "Not a file: " + os.path.basename(archive)}, 1)
    folder = os.path.dirname(archive)
    # unpacked into a hidden folder first, so a half-done or failed one leaves nothing behind but that
    work = tempfile.mkdtemp(prefix=".extracting-", dir=folder)
    try:
        r = subprocess.run(["bsdtar", "-xf", archive, "-C", work], capture_output=True, text=True)
        if r.returncode != 0 and archive.lower().endswith(".rar") and shutil.which("unrar"):
            for name in os.listdir(work):
                delete_now(os.path.join(work, name))
            r = subprocess.run(["unrar", "x", "-o-", "-idq", archive, work + os.sep], capture_output=True, text=True)
        if r.returncode != 0:
            lines = [l for l in r.stderr.strip().splitlines() if "Error exit delayed" not in l]
            msg = (lines or ["Could not unpack it"])[0]
            out({"error": msg.replace(work + os.sep, "").replace(work, "")}, 1)
        top = os.listdir(work)
        if not top:
            out({"error": "The archive is empty"}, 1)
        if len(top) == 1:
            name = free_name(folder, top[0])
            os.rename(os.path.join(work, top[0]), os.path.join(folder, name))
        else:
            name = free_name(folder, archive_stem(os.path.basename(archive)))
            os.chmod(work, 0o755)                       # mkdtemp's folder is private; a made folder is not
            os.rename(work, os.path.join(folder, name))
            work = ""
        out({"ok": True, "name": name})
    finally:
        if work and os.path.isdir(work):
            shutil.rmtree(work, ignore_errors=True)


# ---------- drives: the partition in use (/) and plugged-in ones ----------
def devices():
    raw = subprocess.run(["lsblk", "-J", "-o", "NAME,PATH,PKNAME,TYPE,FSTYPE,LABEL,MOUNTPOINT,RM,HOTPLUG,TRAN,SIZE"],
                         capture_output=True, text=True, check=True).stdout
    found = []

    def walk(nodes, parent_hot):
        for n in nodes:
            hot = parent_hot or bool(n.get("rm")) or bool(n.get("hotplug")) or n.get("tran") == "usb"
            kids = n.get("children") or []
            if n.get("mountpoint") == "/":
                found.append({"dev": n["path"], "mount": "/", "label": "System", "removable": False})
            elif hot and n.get("fstype") and n.get("fstype") != "swap" and not kids and n.get("type") in ("part", "disk"):
                found.append({"dev": n["path"], "mount": n.get("mountpoint") or "",
                              "label": n.get("label") or n.get("size") or n["name"], "removable": True})
            walk(kids, hot)
    walk(json.loads(raw).get("blockdevices", []), False)
    found.sort(key=lambda d: d["removable"])
    out({"devices": found})


def mount(dev):
    r = subprocess.run(["udisksctl", "mount", "--no-user-interaction", "-b", dev], capture_output=True, text=True)
    if r.returncode != 0:
        out({"error": (r.stderr.strip().splitlines() or ["Could not open the drive"])[-1]}, 1)
    m = re.search(r" at (.+?)\.?$", r.stdout.strip())
    out({"mount": m.group(1) if m else ""})


def eject(dev):
    r = subprocess.run(["udisksctl", "unmount", "--no-user-interaction", "-b", dev], capture_output=True, text=True)
    if r.returncode != 0 and "not mounted" not in r.stderr.lower():
        out({"error": (r.stderr.strip().splitlines() or ["The drive is in use"])[-1]}, 1)
    parent = subprocess.run(["lsblk", "-no", "PKNAME", dev], capture_output=True, text=True).stdout.strip()
    subprocess.run(["udisksctl", "power-off", "--no-user-interaction", "-b", "/dev/" + parent if parent else dev],
                   capture_output=True, text=True)
    out({"ok": True})


def apps(path):
    info = Gio.File.new_for_path(path).query_info("standard::content-type", Gio.FileQueryInfoFlags.NONE, None)
    ctype = info.get_content_type()
    default = Gio.AppInfo.get_default_for_type(ctype, False)
    seen, result = set(), []
    for app in ([default] if default else []) + list(Gio.AppInfo.get_all_for_type(ctype)):
        app_id = app.get_id()
        if not app_id or app_id in seen or not app.should_show():
            continue
        seen.add(app_id)
        icon = app.get_icon()
        name = icon.get_names()[0] if isinstance(icon, Gio.ThemedIcon) and icon.get_names() else (
            icon.to_string() if icon else "")
        result.append({"id": app_id, "name": app.get_display_name(), "icon": name,
                       "default": bool(default and app_id == default.get_id())})
    out({"type": ctype, "apps": result})


def open_with(app_id, path):
    app = Gio.DesktopAppInfo.new(app_id)
    if app is None:
        out({"error": "No application " + app_id}, 1)
    app.launch([Gio.File.new_for_path(path)], None)
    out({"ok": True})


def paste(mode, policy, dest, paths):
    if not os.path.isdir(dest):
        out({"error": "Not a folder: " + dest}, 1)
    pairs = []
    for src in paths:
        src = os.path.abspath(src)
        if not os.path.lexists(src):
            continue
        target = os.path.join(dest, os.path.basename(src))
        if os.path.isdir(src) and (os.path.abspath(dest) + os.sep).startswith(src + os.sep):
            out({"error": "Cannot put a folder inside itself: " + os.path.basename(src)}, 1)
        pairs.append((src, target))
    conflicts = [os.path.basename(t) for s, t in pairs if os.path.lexists(t) and s != t]
    if policy == "ask" and conflicts:
        out({"conflicts": conflicts})
    done, errors = 0, []
    for src, target in pairs:
        if src == target:
            continue  # pasted where it already is
        try:
            if os.path.lexists(target):
                if policy == "skip":
                    continue
                trash(target)
            if mode == "move":
                shutil.move(src, target)
            elif os.path.isdir(src) and not os.path.islink(src):
                shutil.copytree(src, target, symlinks=True)
            else:
                shutil.copy2(src, target, follow_symlinks=False)
            done += 1
        except Exception as e:  # report and carry on with the rest
            errors.append(os.path.basename(src) + ": " + str(e))
    out({"done": done, "errors": errors})


def rename(path, name):
    if not name or "/" in name or name in (".", ".."):
        out({"error": "Not a valid name"}, 1)
    target = os.path.join(os.path.dirname(path), name)
    if target == path:
        out({"ok": True, "path": target})
    if os.path.lexists(target):
        out({"error": "“" + name + "” already exists"}, 1)
    os.rename(path, target)
    out({"ok": True, "path": target})


def new_folder(folder):
    name, n = "New Folder", 1
    while os.path.lexists(os.path.join(folder, name)):
        n += 1
        name = "New Folder " + str(n)
    os.mkdir(os.path.join(folder, name))
    out({"ok": True, "name": name})


def new_file(folder):
    name, n = "New File.txt", 1
    while True:
        try:
            # created only if the name is free, so nothing already there is ever opened or emptied
            os.close(os.open(os.path.join(folder, name), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644))
            break
        except FileExistsError:
            n += 1
            name = "New File " + str(n) + ".txt"
    out({"ok": True, "name": name})


def main(argv):
    # the shell runs with umask 077 (scripts/swap-shell.py); new folders and files get the desktop's usual 022, as
    # Dolphin makes them
    os.umask(0o022)
    if not argv:
        out({"error": "No command"}, 2)
    cmd, args = argv[0], argv[1:]
    try:
        if cmd == "apps" and len(args) == 1:
            apps(args[0])
        elif cmd == "open-with" and len(args) == 2:
            open_with(*args)
        elif cmd == "paste" and len(args) >= 4 and args[0] in ("copy", "move") and args[1] in ("ask", "replace", "skip"):
            paste(args[0], args[1], args[2], args[3:])
        elif cmd == "rename" and len(args) == 2:
            rename(*args)
        elif cmd == "new-folder" and len(args) == 1:
            new_folder(args[0])
        elif cmd == "new-file" and len(args) == 1:
            new_file(args[0])
        elif cmd == "remove" and args:
            remove(args)
        elif cmd == "restore" and len(args) >= 2 and args[0] in ("ask", "replace", "skip"):
            restore(args[0], args[1:])
        elif cmd == "empty-trash" and not args:
            empty_trash()
        elif cmd == "extract" and len(args) == 1:
            extract(args[0])
        elif cmd == "devices" and not args:
            devices()
        elif cmd == "mount" and len(args) == 1:
            mount(args[0])
        elif cmd == "eject" and len(args) == 1:
            eject(args[0])
        elif cmd == "trash" and args:
            errors = []
            for p in args:
                try:
                    trash(p)
                except Exception as e:
                    errors.append(os.path.basename(p) + ": " + str(e))
            out({"done": len(args) - len(errors), "errors": errors})
        else:
            out({"error": "Bad command"}, 2)
    except SystemExit:
        raise
    except Exception as e:
        out({"error": str(e)}, 1)


if __name__ == "__main__":
    main(sys.argv[1:])
