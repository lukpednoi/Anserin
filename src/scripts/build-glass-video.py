#!/usr/bin/env python3
"""Build the local Qt video-sink bridge only when its source changed."""
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "src/quickshell/native/video"
LIBRARY = SOURCE / "libanserinvideo.so"


def main():
    qt_version = subprocess.check_output(["pkg-config", "--modversion", "Qt6Core"], text=True).strip()
    build = ROOT / ".lab-data/glass-video-build"
    version_file = build / "qt-version"
    inputs = [SOURCE / "plugin.cpp", SOURCE / "CMakeLists.txt"]
    if (LIBRARY.is_file() and version_file.is_file() and version_file.read_text() == qt_version
            and all(path.stat().st_mtime <= LIBRARY.stat().st_mtime for path in inputs)):
        return
    if not shutil.which("cmake") or not shutil.which("c++"):
        raise RuntimeError("Glass video needs the installed Qt development tools and C++ compiler; see README.md")
    subprocess.run(["cmake", "-S", str(SOURCE), "-B", str(build), "-DCMAKE_BUILD_TYPE=Release"], check=True)
    subprocess.run(["cmake", "--build", str(build), "--parallel", "2"], check=True)
    version_file.write_text(qt_version)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
