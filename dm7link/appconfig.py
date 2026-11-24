"""DM7 Link's settings file: the panel's `Config`, plus the keys only this app has.

The panel's loader keeps only the keys it knows (its DEFAULTS) and drops the rest on reading,
so `features`, `superrack_adapter` and the show-file keys would be lost at every restart without this.
"""
from __future__ import annotations

import json

from dm7gui.config import Config

APP_KEYS = {"features": dict, "superrack_adapter": str,
            # show files (`showfile.py`); `offline` is the panel's own key now
            "show_path": str, "show_recent": list, "show_print": str}


class AppConfig(Config):
    def load(self) -> bool:
        found = super().load()
        try:
            raw = json.loads(self.path.read_text("utf-8"))
        except (OSError, ValueError):
            return found
        if isinstance(raw, dict):
            for key, kind in APP_KEYS.items():
                if isinstance(raw.get(key), kind):
                    self.data[key] = raw[key]
        return found
