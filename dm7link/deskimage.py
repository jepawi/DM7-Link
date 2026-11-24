"""The desk inside a show file: what the console held, so a show can be prepared without it.

Two parts, kept apart because they answer different questions:

    record   what the show was BUILT AGAINST -- the scene list (bank, number, title, file) and
             the channel names. Small JSON. Compared with the desk at the next connect
             (`mismatch.py`), so a scene that moved or a channel renamed since is found before
             a cue fires the wrong scene.
    image    the desk itself, for offline work -- the console's sync stream (its parameter tree
             and every value at connect), each whole area the desk re-sent since (a scene
             recall sends Mixing, Processing, FX and PremiumRack whole), and every single change
             after that. Replayed into the value store, it is a console the app cannot tell from
             a real one, with the network missing.

The sync stream is ~5 MB and deflates to ~60 KB: it is mostly zeros.

A laptop that has never seen a desk gets the blank DM7 (`dm7gui/blank-desk.bin`, a real
console's sync with nothing stored): every control is there to build macros against, and no
scene. The image half lives in `dm7gui.deskimage`, shared with the panel.
"""
from __future__ import annotations

import time

from rackbridge import channelmidi

NAMED_FAMILIES = ("Input", "Mix", "Matrix", "Stereo")    # DCA names are not read by the app


# -- the record ---------------------------------------------------------------
def record(store, book, console_name: str = "") -> dict:
    """The desk as the show sees it: {name, firmware, captured, scenes, channels}.

    `book` is the SceneBridge's SceneBook (read fresh). Channel names are kept only where the
    desk has one: a channel the desk prints as its number has nothing to follow.
    """
    from dm7gui import wavesdesk
    scenes = []
    if book is not None and book.ready:
        book.refresh()
        for bank in (0, 1):
            for s in book.scenes(bank):
                scenes.append({"bank": bank, "number": str(s["number"]),
                               "title": str(s.get("title") or ""), "file": str(s.get("file") or "")})
    channels = {}
    if store is not None and store.value_state("Mixing") == "ready":
        for _n, family, _prefix, count in channelmidi.FAMILIES:
            if family not in NAMED_FAMILIES:
                continue
            for element in range(count):
                try:
                    name = wavesdesk.channel_name(store, family, element)
                except (KeyError, IndexError, TypeError):
                    continue
                label = channelmidi.label(family, element)
                if name and name != label:
                    channels[label] = name
    return {"name": str(console_name or ""),
            "firmware": store.firmware() if store is not None and store.ready else "",
            "captured": time.strftime("%Y-%m-%d %H:%M"),
            "scenes": scenes, "channels": channels}


def record_ready(store, book) -> bool:
    """Can a record be taken now: the scene list and the channel names are both read."""
    if store is None or not store.ready or book is None:
        return False
    book.want_values()
    if store.value_state("Mixing") == "none":
        store.request("Mixing")
    return book.ready and store.value_state("Mixing") == "ready"


# -- the image: the panel's own (`dm7gui.deskimage`) ----------------------------
from dm7gui.deskimage import (AreaRecorder, blank, capture, pack, read_files,  # noqa: E402,F401
                              replay, unpack, write_files)
