"""Build DM7 Link as one application folder: `python3 build.py`.

    macOS     dist/DM7 Link.app
    Windows   dist/DM7 Link/DM7 Link.exe

Needs `pip install pyinstaller` on top of requirements.txt, and is run on the system it builds
for (PyInstaller does not cross-compile). The console library (`dm7`), the panel modules DM7 Link
runs (`dm7gui`) and the rack bridge (`rackbridge`) are taken from this repository and bundled.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
SEP = os.pathsep


def main() -> int:
    icon = HERE / "dm7-link" / ("icon.icns" if sys.platform == "darwin" else "icon.ico")
    args = [
        sys.executable, "-m", "PyInstaller", "--noconfirm", "--clean", "--windowed",
        "--name", "DM7 Link",
        "--paths", str(REPO), "--paths", str(REPO / "dm7-gui"), "--paths", str(REPO / "rack-bridge"),
        "--add-data", f"{HERE / 'dm7link' / 'qml'}{SEP}dm7link/qml",
        "--add-data", f"{HERE / 'dm7link' / 'fonts'}{SEP}dm7link/fonts",
        "--add-data", f"{HERE / 'dm7link' / 'icon.png'}{SEP}dm7link",
        "--add-data", f"{REPO / 'dm7-gui' / 'dm7gui' / 'blank-desk.bin'}{SEP}dm7gui",
        "--collect-submodules", "dm7", "--collect-submodules", "dm7gui",
        "--collect-submodules", "rackbridge",
        "--hidden-import", "sounddevice", "--hidden-import", "psutil",
        "--osx-bundle-identifier", "app.dm7link",
    ]
    if icon.exists():
        args += ["--icon", str(icon)]
    args.append(str(HERE / "run.py"))
    code = subprocess.call(args, cwd=str(HERE))
    plist = HERE / "dist" / "DM7 Link.app" / "Contents" / "Info.plist"
    if code == 0 and plist.exists():
        # Without this macOS refuses the audio input silently: timecode would never arrive.
        import plistlib
        info = plistlib.loads(plist.read_bytes())
        info["NSMicrophoneUsageDescription"] = "DM7 Link reads timecode (LTC) from an audio input."
        from dm7link import __version__
        info["CFBundleShortVersionString"] = __version__
        plist.write_bytes(plistlib.dumps(info))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
