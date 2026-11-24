"""Where the code DM7 Link is built from lives, and where its settings go.

DM7 Link is a front end. The console connection, the Waves engine, the scene list and the
timecode decoder are the same modules the DM7 touch panel runs (`dm7/`, `dm7-gui/dm7gui/`,
`rack-bridge/rackbridge/`), found beside this folder in the repository -- or, in a frozen
build, inside the bundle, where PyInstaller put them.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

APP_NAME = "DM7 Link"
HERE = Path(__file__).resolve().parent                  # dm7link/
ROOT = HERE.parent                                      # dm7-link/


def _bundle() -> Path | None:
    base = getattr(sys, "_MEIPASS", None)
    return Path(base) if base else None


def code_roots() -> list[Path]:
    """The folders that hold `dm7`, `dm7gui` and `rackbridge`, in import order."""
    bundle = _bundle()
    if bundle is not None:
        return [bundle]
    repo = ROOT.parent
    return [repo, repo / "dm7-gui", repo / "rack-bridge"]


def install() -> None:
    for root in reversed(code_roots()):
        text = str(root)
        if root.is_dir() and text not in sys.path:
            sys.path.insert(0, text)


def resource(*parts: str) -> Path:
    """A file shipped with the app (QML, fonts, icon)."""
    bundle = _bundle()
    base = bundle / "dm7link" if bundle is not None else HERE
    return base.joinpath(*parts)


def data_dir() -> Path:
    """Settings, the rack and scene tables, the cue list and the logs -- one folder per user.

        macOS     ~/Library/Application Support/DM7 Link
        Windows   %APPDATA%\\DM7 Link
        Linux     $XDG_CONFIG_HOME/dm7link  (~/.config/dm7link)
        override  $DM7LINK_HOME
    """
    explicit = os.environ.get("DM7LINK_HOME")
    if explicit:
        return Path(explicit).expanduser()
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / APP_NAME
    if os.name == "nt":
        return Path(os.environ.get("APPDATA") or Path.home()) / APP_NAME
    base = os.environ.get("XDG_CONFIG_HOME")
    return (Path(base).expanduser() if base else Path.home() / ".config") / "dm7-link"
