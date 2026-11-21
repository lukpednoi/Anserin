#!/usr/bin/env python3
"""Build Anserin's native core plugin (src/quickshell/native/core) only when its source or Qt changed.

Exit 0 when the plugin is ready. The shell falls back to its older ways (pw-play for sounds) otherwise."""
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "src/quickshell/native/core"
BUILD = ROOT / ".lab-data/core-build"
LIBRARY = BUILD / "module/libanserincore.so"   # with its qmldir; imported by path from the shell
TOOL = BUILD / "bin/anserin-core"              # the helper program the scripts call
WALLPAPER = BUILD / "bin/anserin-wallpaper"    # the wallpaper indexer


def main():
    qt_version = subprocess.check_output(["pkg-config", "--modversion", "Qt6Core"], text=True).strip()
    build = BUILD
    version_file = build / "qt-version"
    inputs = [p for p in SOURCE.rglob("*") if p.suffix in (".cpp", ".h", ".xml") or p.name in ("CMakeLists.txt", "qmldir")]
    built = [LIBRARY, TOOL, WALLPAPER]
    if (all(p.is_file() for p in built) and version_file.is_file() and version_file.read_text() == qt_version
            and all(path.stat().st_mtime <= min(p.stat().st_mtime for p in built) for path in inputs)):
        return
    if not shutil.which("cmake") or not shutil.which("c++"):
        raise RuntimeError("Anserin core needs cmake, a C++ compiler, wayland-scanner and the Qt, PipeWire, libsndfile, Wayland and libsystemd headers")
    build.mkdir(parents=True, exist_ok=True)
    subprocess.run(["cmake", "-S", str(SOURCE), "-B", str(build), "-DCMAKE_BUILD_TYPE=Release"],
                   check=True, stdout=subprocess.DEVNULL)
    subprocess.run(["cmake", "--build", str(build), "--parallel", "2"], check=True, stdout=subprocess.DEVNULL)
    version_file.write_text(qt_version)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
