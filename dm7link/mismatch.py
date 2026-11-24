"""What changed on the desk since the show was built, and what to do about it.

A show refers to the desk in two ways that can go stale while the app is not looking:

    scenes     a cue recalls `012.00`; a macro's SCENE block or "scene recalled" trigger names
               one; the Waves scene table maps `A 12` to a SuperRack snapshot.
    channels   the Waves channel table sends `CH 5` to a rack.

Each is a NUMBER, and the desk renumbers, re-titles, deletes and renames freely. So the show
file keeps, next to the show, what the desk held when the show was last in step with it
(`deskimage.record`): each scene's title and each channel's name. At the next connect the two
are compared, and every reference whose scene or channel is not what it was becomes one issue:

    moved      scene 12 "Band on" is now scene 14 -- the same title, another number
               (follow it / keep the number / remove the reference)
    renamed    scene 12 is still there but is now called something else (keep / remove)
    missing    scene 12 is gone and nothing carries its title (keep / remove)

A channel is the same, with its name in place of the title. Channels are only checked while
the Waves table is kept by hand: with "Follow SuperRack's patch" on, the table is read from the
patch and follows the desk by itself.

A reference the show never saw a title for (a number typed on the keypad offline) can only be
`missing` or fine. Pure Python, no Qt: `check.py` tests it as it is.
"""
from __future__ import annotations

from dm7.codec import scenes as codec
from rackbridge import channelmidi

BANKS = ("A", "B")


def _num(text) -> str:
    """Any spelling of a scene number -> the desk's `012.00`; '' when it is not one."""
    text = codec.normalise(str(text or "").strip())
    return text if text[:1].isdigit() else ""


def _short(number: str) -> str:
    whole, _, sub = str(number).partition(".")
    try:
        w, s = int(whole), int(sub or 0)
    except ValueError:
        return str(number)
    return f"{w}" + (f".{s:02d}" if s else "")


def _waves_scene(label: str):
    """`A 12.05` -> (0, '012.05'); None if it is not a scene label."""
    hit = channelmidi.parse_scene(str(label))
    if hit is None:
        return None
    bank, whole, sub = hit
    return bank, f"{whole:03d}.{sub:02d}"


def _waves_label(bank: int, number: str) -> str:
    whole, _, sub = number.partition(".")
    return channelmidi.scene_label(bank, int(whole), int(sub or 0))


def _walk_scenes(node, found: list) -> None:
    """Every dict in a macro that names a scene by number (SCENE blocks, recalled triggers)."""
    if isinstance(node, dict):
        if "scene" in node and _num(node.get("scene")):
            found.append(node)
        for value in node.values():
            _walk_scenes(value, found)
    elif isinstance(node, list):
        for item in node:
            _walk_scenes(item, found)


def scene_refs(show: dict, bank: int) -> dict:
    """{(bank, number): {"cues": [cue], "macros": {macro_id: [holder]}, "waves": [label]}}."""
    refs: dict = {}

    def at(key):
        return refs.setdefault(key, {"cues": [], "macros": {}, "waves": []})

    for cue in (show.get("cues") or {}).get("cues") or []:
        if str(cue.get("kind") or "") == "scene" and _num(cue.get("scene")):
            at((bank, _num(cue["scene"])))["cues"].append(cue)
    for macro in (show.get("macros") or {}).get("macros") or []:
        holders: list = []
        _walk_scenes([macro.get("blocks") or [], macro.get("triggers") or []], holders)
        for holder in holders:
            at((bank, _num(holder["scene"])))["macros"].setdefault(str(macro.get("id")), []) \
                .append(holder)
    racks = show.get("racks") or {}
    for label in list((racks.get("snap_map") or {}).keys()) + list(racks.get("snap_skip") or []):
        hit = _waves_scene(label)
        if hit is not None:
            at(hit)["waves"].append(label)
    return refs


def _uses(ref: dict) -> str:
    parts = []
    if ref["cues"]:
        n = len(ref["cues"])
        parts.append(f"{n} cue{'' if n == 1 else 's'}")
    if ref["macros"]:
        n = len(ref["macros"])
        parts.append(f"{n} macro{'' if n == 1 else 's'}")
    if ref["waves"]:
        parts.append("Waves scene table")
    return " · ".join(parts)


def _scene_name(bank: int, number: str, title: str, banks: bool) -> str:
    where = f"{BANKS[bank]} " if banks else ""
    return f"Scene {where}{_short(number)}" + (f" “{title}”" if title else "")


def find(show: dict, was: dict, now: dict, bank: int = 0) -> list[dict]:
    """Every reference in `show` the desk no longer matches. `was` is the record the show was
    built against, `now` the desk's record at this connect (both `deskimage.record`)."""
    issues: list[dict] = []
    old = {(int(s["bank"]), _num(s["number"])): str(s.get("title") or "")
           for s in (was or {}).get("scenes") or []}
    new = {(int(s["bank"]), _num(s["number"])): str(s.get("title") or "")
           for s in (now or {}).get("scenes") or []}
    two_banks = any(b == 1 for b, _ in new) or any(b == 1 for b, _ in old)
    for (b, number), ref in sorted(scene_refs(show, bank).items()):
        title = old.get((b, number))
        here = new.get((b, number))
        if title is None:
            if here is not None:
                continue                         # never seen, and there: nothing to compare
            kind = "missing"
        elif here == title:
            continue
        else:
            kind = None
        follow = sorted((n for (bb, n), t in new.items() if bb == b and title and t == title
                         and n != number), key=lambda n: tuple(int(x) for x in n.split(".")))
        if kind is None:
            kind = "moved" if follow else "missing" if here is None else "renamed"
        options = [{"value": "follow:" + n, "label": "Use " + _scene_name(b, n, title, two_banks)}
                   for n in follow]
        options.append({"value": "keep", "label": f"Keep {_short(number)}"
                        + (f" (now “{here}”)" if here else " (not on the desk)")})
        options.append({"value": "clear", "label": "Remove the reference"})
        now_text = ("not on the desk" if here is None
                    else f"now “{here}”" if here else "now untitled")
        if kind == "moved":
            now_text = "now " + ", ".join(_scene_name(b, n, "", two_banks) for n in follow) + \
                       ("" if here is None else f"; {_short(number)} is “{here}”" if here
                        else f"; {_short(number)} is untitled")
        issues.append({"id": f"scene:{b}:{number}", "kind": kind, "what": "scene",
                       "bank": b, "number": number,
                       "title": _scene_name(b, number, title or "", two_banks),
                       "now": now_text, "uses": _uses(ref),
                       "options": options, "choice": options[0]["value"]})

    racks = show.get("racks") or {}
    if not racks.get("follow_patch", True):
        names_was = dict((was or {}).get("channels") or {})
        names_now = dict((now or {}).get("channels") or {})
        for label, rack in sorted((racks.get("map") or {}).items()):
            name = names_was.get(label, "")
            if not name or names_now.get(label, "") == name:
                continue
            prefix = label.split()[0]
            follow = [lb for lb, nm in names_now.items()
                      if nm == name and lb != label and lb.split()[0] == prefix]
            follow.sort(key=lambda lb: channelmidi.parse_label(lb) or ("", 0))
            current = names_now.get(label, "")
            options = [{"value": "follow:" + lb, "label": f"Use {lb} “{name}”"} for lb in follow]
            options.append({"value": "keep", "label": f"Keep {label}"
                            + (f" (now “{current}”)" if current else " (now unnamed)")})
            options.append({"value": "clear", "label": "Remove from the Waves table"})
            issues.append({"id": f"channel:{label}", "kind": "moved" if follow else "renamed",
                           "what": "channel", "label": label,
                           "title": f"{label} “{name}”",
                           "now": ("now " + ", ".join(follow)) if follow
                           else (f"now “{current}”" if current else "now unnamed"),
                           "uses": f"Waves rack {rack}", "options": options,
                           "choice": options[0]["value"]})
    return issues


def resolve(show: dict, issues: list[dict], choices: dict, bank: int = 0) -> int:
    """Apply what was chosen ({issue id: option value}) to `show` in place. Returns how many
    references were changed. An issue with no choice keeps its default."""
    refs = scene_refs(show, bank)
    racks = show.setdefault("racks", {})
    macros = {str(m.get("id")): m for m in (show.get("macros") or {}).get("macros") or []}
    changed = 0
    # Collect every rewrite first, then apply: two scenes swapping numbers must not chase
    # each other through the table.
    waves_moves: list = []
    for issue in issues:
        pick = str(choices.get(issue["id"], issue["choice"]))
        if pick == "keep":
            continue
        target = pick.split(":", 1)[1] if pick.startswith("follow:") else ""
        if issue["what"] == "scene":
            ref = refs.get((issue["bank"], issue["number"]))
            if ref is None:
                continue
            for cue in ref["cues"]:
                cue["scene"] = target
                if not target:
                    cue["armed"] = False
                changed += 1
            for macro_id, holders in ref["macros"].items():
                for holder in holders:
                    holder["scene"] = target
                    changed += 1
                if not target and macro_id in macros:
                    macros[macro_id]["armed"] = False
            for label in ref["waves"]:
                waves_moves.append((label, _waves_label(issue["bank"], target) if target else ""))
                changed += 1
        elif issue["what"] == "channel":
            table = racks.setdefault("map", {})
            rack = table.pop(issue["label"], None)
            if rack is None:
                continue
            if target:
                table[target] = rack
            changed += 1
    if waves_moves:
        snap_map = dict(racks.get("snap_map") or {})
        skip = set(racks.get("snap_skip") or [])
        moved_map, moved_skip = {}, set()
        for label, to in waves_moves:
            if label in snap_map:
                name = snap_map.pop(label)
                if to:
                    moved_map[to] = name
            if label in skip:
                skip.discard(label)
                if to:
                    moved_skip.add(to)
        snap_map.update(moved_map)
        racks["snap_map"] = snap_map
        racks["snap_skip"] = sorted(skip | moved_skip,
                                    key=lambda lb: channelmidi.parse_scene(lb) or (9, 0, 0))
    return changed
