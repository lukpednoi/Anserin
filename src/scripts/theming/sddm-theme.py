#!/usr/bin/env python3
"""Inspect SDDM or explicitly install Anserin's two themes with authentication."""
import configparser
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import stat
import sys
import tempfile

SOURCE = Path(__file__).resolve().parents[3] / "config/sddm/themes"
STYLES = {"old": "material-you", "new": "material-you-new"}
DROPIN = "99-anserin.conf"
# Hyprland plus Anserin; the New theme's star chip selects this session.
SESSION = "anserin-hyprland.desktop"
SESSION_CONTENT = """[Desktop Entry]
Name=Hyprland (Anserin)
Comment=Hyprland with the Anserin shell
Exec=env ANSERIN_SESSION=1 /usr/bin/start-hyprland
Type=Application
DesktopNames=Hyprland
"""


def configuration(system=Path("/"), extra=None):
    result = configparser.ConfigParser(interpolation=None, strict=False)
    result.optionxform = str
    paths = sorted((system / "usr/lib/sddm/sddm.conf.d").glob("*.conf"))
    custom = list((system / "etc/sddm.conf.d").glob("*.conf"))
    if extra is not None:
        custom = list(set(custom + [system / "etc/sddm.conf.d" / DROPIN]))
    paths += sorted(custom)
    paths.append(system / "etc/sddm.conf")
    for path in paths:
        if extra is not None and path == system / "etc/sddm.conf.d" / DROPIN:
            result.read_string(extra)
        elif path.exists():
            result.read(path)
    return result


def status(system=Path("/")):
    conf = configuration(system)
    current = conf.get("Theme", "Current", fallback="")
    directory = conf.get("Theme", "ThemeDir", fallback="/usr/share/sddm/themes")
    style = next((key for key, value in STYLES.items() if value == current), "") if directory in ("/usr/share/sddm/themes", "/usr/share/sddm/themes/anserin") else ""
    return {"style": style, "theme": current, "directory": directory, "managed": directory == "/usr/share/sddm/themes/anserin"}


def content(style):
    if style not in STYLES:
        raise ValueError("Unknown SDDM style")
    return "[Theme]\nCurrent=" + STYLES[style] + "\nThemeDir=/usr/share/sddm/themes/anserin\n"


def plan(style):
    return {
        "style": style,
        "themes": "/usr/share/sddm/themes/anserin/",
        "configuration": "/etc/sddm.conf.d/" + DROPIN,
        "session": "/usr/share/wayland-sessions/" + SESSION,
        "content": content(style),
        "backup": "Changed files are moved to timestamped _to_delete/ directories beside their originals",
        "restart": False,
    }


def safe(path):
    if any(p.is_symlink() for p in (path, *path.parents)):
        raise ValueError("Refusing a linked system path: " + str(path))


def copy_themes(source, destination):
    for theme in STYLES.values():
        base = source / theme
        safe(base)
        for directory, folders, filenames, descriptor in os.fwalk(base, follow_symlinks=False):
            for name in folders:
                if not stat.S_ISDIR(os.stat(name, dir_fd=descriptor, follow_symlinks=False).st_mode):
                    raise ValueError("Linked directories are not allowed in SDDM themes")
            output = destination / theme / Path(directory).relative_to(base)
            output.mkdir(mode=0o755, parents=True, exist_ok=True)
            output.chmod(0o755)
            for name in filenames:
                with os.fdopen(os.open(name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=descriptor), "rb") as handle:
                    if not stat.S_ISREG(os.fstat(handle.fileno()).st_mode):
                        raise ValueError("SDDM assets must be regular files")
                    path = output / name
                    path.write_bytes(handle.read())
                    path.chmod(0o644)
        for name in ("Main.qml", "metadata.desktop", "theme.conf"):
            if not (destination / theme / name).is_file():
                raise ValueError("Missing SDDM theme file: " + theme + "/" + name)
    (destination / ".anserin-managed.json").write_text(json.dumps({"version": 1, "themes": list(STYLES.values())}))


def apply(style, source=SOURCE, system=Path("/")):
    settings = content(style)
    planned = configuration(system, settings)
    if planned.get("Theme", "Current") != STYLES[style] or planned.get("Theme", "ThemeDir") != "/usr/share/sddm/themes/anserin":
        raise ValueError("Another SDDM configuration overrides 99-anserin.conf; no files were changed")
    themes = system / "usr/share/sddm/themes"
    target = themes / "anserin"
    config = system / "etc/sddm.conf.d" / DROPIN
    session = system / "usr/share/wayland-sessions" / SESSION
    safe(target)
    safe(config)
    safe(session)
    if not themes.is_dir() or not config.parent.is_dir():
        raise ValueError("SDDM system directories are missing")
    if target.exists() and not (target / ".anserin-managed.json").is_file():
        raise ValueError("An unowned Anserin SDDM directory already exists; keeping it intact")
    if config.exists() and (not config.is_file() or config.read_text() not in (content("old"), content("new"))):
        raise ValueError("An unowned 99-anserin.conf already exists; keeping it intact")
    if session.exists() and (not session.is_file() or session.read_text() != SESSION_CONTENT):
        raise ValueError("An unowned " + SESSION + " already exists; keeping it intact")
    # Without Hyprland the session could not start, so the star chip stays hidden.
    add_session = session.parent.is_dir() and (system / "usr/bin/start-hyprland").is_file() and not session.exists()
    stamp = datetime.now(timezone.utc).strftime("anserin-%Y%m%dT%H%M%S.%fZ")
    backups = []
    installed = False
    with tempfile.TemporaryDirectory(prefix=".anserin-", dir=themes) as directory:
        staged = Path(directory) / "anserin"
        copy_themes(source, staged)
        staged.chmod(0o755)
        with tempfile.NamedTemporaryFile(mode="w", dir=config.parent, delete=False) as handle:
            pending = Path(handle.name)
            pending_session = None
            try:
                handle.write(settings)
                handle.flush()
                os.fsync(handle.fileno())
                pending.chmod(0o644)
                if add_session:
                    with tempfile.NamedTemporaryFile(mode="w", dir=session.parent, prefix=".anserin-", delete=False) as entry:
                        pending_session = Path(entry.name)
                        entry.write(SESSION_CONTENT)
                        entry.flush()
                        os.fsync(entry.fileno())
                    pending_session.chmod(0o644)
                    # First, so a failure leaves every other file untouched; a stray
                    # entry is harmless and accepted as owned by the next install.
                    pending_session.replace(session)
                for path in (target, config):
                    if path.exists():
                        backup = path.parent / "_to_delete" / stamp / path.name
                        safe(backup)
                        backup.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
                        path.replace(backup)
                        backups.append((path, backup))
                staged.replace(target)
                installed = True
                pending.replace(config)
            except OSError:
                if installed:
                    failed = themes / "_to_delete" / (stamp + "-failed") / "anserin"
                    failed.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
                    target.replace(failed)
                for path, backup in reversed(backups):
                    backup.replace(path)
                raise
            finally:
                pending.unlink(missing_ok=True)
                if pending_session is not None:
                    pending_session.unlink(missing_ok=True)
    return dict(status(system), backups=[str(path) for _, path in backups], restart=False)


def main():
    args = sys.argv[1:]
    if args == ["--status"]:
        return status()
    if len(args) == 2 and args[0] == "--plan":
        return plan(args[1])
    if len(args) == 2 and args[0] == "--apply":
        if os.geteuid() != 0:
            raise ValueError("SDDM needs administrator authentication; no files were changed")
        # Never trust a caller-controlled Python environment or arbitrary destinations.
        return apply(args[1])
    raise ValueError("Usage: sddm-theme.py --status | --plan old|new | --apply old|new")


if __name__ == "__main__":
    try:
        print(json.dumps(main()))
    except (OSError, ValueError, KeyError, configparser.Error) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
