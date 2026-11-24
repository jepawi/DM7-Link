"""SHOW FILES: one file holds a whole show, and another can be opened in its place.

A show file (`.dm7show`) is a zip:

    show.json           the show
        settings        features (Waves / Timecode / Macros on or off); the Waves link's show
                        settings (what follows the desk, the card, the tempo source); the
                        timecode frame rate; and, under `rig`, the audio interface and input
                        the LTC came in on
        racks           the Waves tables -- channel -> rack, scene -> snapshot, scenes left
                        out -- and how the link behaves (Show mode, follow the patch, ...)
        cues            the cue list, songs and part names, as `cues.json` holds them
        macros          every macro, as `macros.json` holds them
        desk            what the desk held when the show was last in step with it:
                        scene list, channel names (`deskimage.record`)
    desk/...            the desk itself, for working offline (`deskimage.pack`)

What stays with THIS computer and is never in a show: the console address, SuperRack's
adapter, the ProLink port and address, SuperRack's session folder, the MIDI port. The rig's
audio interface is in the file, and is taken only when this computer has one by that name.

The show being worked on is always the set of files in the settings folder (`config.json`,
`racks.json`, `cues.json`, `macros.json`, plus `desk.json` and `desk-image.zip`), exactly as
before show files existed: every edit lands there at once. SAVE copies them into the show file,
OPEN copies a show file into them and every engine re-reads -- no restart.

THE DESK CHECK. While a console is connected (never offline), the show's references to it --
scene numbers in cues, macros and the Waves scene table, channels in the Waves rack table --
are compared with what the show was built against (`mismatch.find`). Run at startup, when a
show is opened, at every connect, and whenever the desk's scene list changes. Nothing found:
the desk's record is taken as the show's. Something found: the window asks, and the record is
only taken once it has been answered -- LATER leaves it, so the question comes back.
"""
from __future__ import annotations

import copy
import hashlib
import json
import os
import tempfile
import time
import zipfile
from pathlib import Path

from PySide6.QtCore import Property, QObject, QTimer, QUrl, Signal, Slot

from rackbridge.settings import DEFAULTS as RACK_DEFAULTS

from . import __version__, audio, deskimage, mismatch

SUFFIX = ".dm7show"
FORMAT = "DM7 Link show"
VERSION = 1
RECENT = 8

WAVES_KEYS = ("send_select", "sel_again", "send_scenes", "send_stores", "send_names",
              "send_tempo", "tempo_source", "card", "card_base")
LTC_KEYS = ("rate",)
RIG_KEYS = ("device", "channel")
RACK_MACHINE = ("midi_port", "midi_channel", "prolink_port", "listen_ip", "session_folder")
RACK_KEYS = tuple(k for k in RACK_DEFAULTS if k not in RACK_MACHINE)
FEATURES = ("waves", "timecode", "macros")


def _write_atomic(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".show-")
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(data)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp, path)
    except OSError:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _json_bytes(payload) -> bytes:
    return (json.dumps(payload, indent=2) + "\n").encode("utf-8")


def write_show(path: Path, show: dict, desk_files: dict[str, bytes]) -> None:
    """The show and its desk as one file, written whole or not at all."""
    import io
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("show.json", _json_bytes(show))
        for name, blob in desk_files.items():
            z.writestr(name, blob, compress_type=zipfile.ZIP_STORED)   # already deflated
    _write_atomic(path, buf.getvalue())


def read_show(path: Path) -> tuple[dict, dict[str, bytes]]:
    """(show, desk files). Raises ValueError with what is wrong in words."""
    try:
        with zipfile.ZipFile(path) as z:
            show = json.loads(z.read("show.json").decode("utf-8"))
            desk = {n: z.read(n) for n in z.namelist() if n.startswith("desk/")}
    except FileNotFoundError:
        raise ValueError("File not found") from None
    except (OSError, KeyError, zipfile.BadZipFile, ValueError):
        raise ValueError("Not a DM7 Link show file") from None
    if not isinstance(show, dict) or show.get("format") != FORMAT:
        raise ValueError("Not a DM7 Link show file")
    if int(show.get("version") or 0) > VERSION:
        raise ValueError("Made by a newer DM7 Link")
    return show, desk


def _documents() -> Path:
    docs = Path.home() / "Documents"
    return docs if docs.is_dir() else Path.home()


def empty_show() -> dict:
    racks = copy.deepcopy({k: RACK_DEFAULTS[k] for k in RACK_KEYS})
    return {"format": FORMAT, "version": VERSION,
            "settings": {"features": {n: True for n in FEATURES}, "waves": {}, "ltc": {},
                         "rig": {}},
            "racks": racks, "cues": {"version": 1, "span": 0, "names": {}, "groups": [],
                                     "cues": []},
            "macros": {"version": 2, "macros": []}, "desk": {}}


class ShowFiles(QObject):
    """The `Show` object the window talks to."""

    changed = Signal()          # name, path, recent, desk
    modifiedChanged = Signal()
    issuesChanged = Signal()    # the desk check found something (or it was answered)
    notice = Signal(str, str)   # (text, tone) for the window's toast

    def __init__(self, data_dir: Path, config, session, scenes, waves, cues, macros, features,
                 store, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.data = Path(data_dir)
        self.config, self.session, self.scenes = config, session, scenes
        self.waves, self.cues, self.macros, self.features = waves, cues, macros, features
        self.store = store
        self.recorder = session.recorder         # the connection keeps whole-area blocks
        self._saved_print = ""
        self._modified = False
        self._issues: list = []
        self._check_due = True                   # at startup
        self._in_step = False                    # the desk record was taken at this connect
        self._record = self._read_record()
        self._clock = QTimer(self)
        self._clock.setInterval(1000)
        self._clock.timeout.connect(self._tick)
        self._clock.start()
        session.wentOnline.connect(self._online)
        session.wentOffline.connect(self._gone)
        scenes.listChanged.connect(self._scenes_moved)
        if not self.config.get("show_print"):
            self._mark_saved()
        else:
            self._saved_print = str(self.config.get("show_print"))

    # -- the working desk -----------------------------------------------------
    @property
    def _desk_json(self) -> Path:
        return self.data / "desk.json"

    @property
    def _desk_zip(self) -> Path:
        return self.data / "desk-image.zip"

    def _read_record(self) -> dict:
        try:
            raw = json.loads(self._desk_json.read_text("utf-8"))
        except (OSError, ValueError):
            return {}
        return raw if isinstance(raw, dict) else {}

    def _write_record(self, record: dict) -> None:
        self._record = dict(record or {})
        try:
            _write_atomic(self._desk_json, _json_bytes(self._record))
        except OSError as exc:
            print(f"[show] could not save the desk record: {exc}")
        self.changed.emit()

    def _desk_files(self) -> dict[str, bytes]:
        try:
            with zipfile.ZipFile(self._desk_zip) as z:
                return {n: z.read(n) for n in z.namelist()}
        except (OSError, zipfile.BadZipFile):
            return {}

    def _write_desk_files(self, files: dict[str, bytes]) -> None:
        if not files:
            try:
                self._desk_zip.unlink()
            except OSError:
                pass
            return
        import io
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w", zipfile.ZIP_STORED) as z:
            for name, blob in files.items():
                z.writestr(name, blob)
        try:
            _write_atomic(self._desk_zip, buf.getvalue())
        except OSError as exc:
            print(f"[show] could not save the desk image: {exc}")

    def image(self) -> tuple:
        """For the offline worker: (the working show's desk image, "show"), or (None, "")."""
        image = deskimage.unpack(self._desk_files())
        return (image, "show") if image is not None else (None, "")

    def _live(self) -> bool:
        """A real console is connected."""
        return bool(self.session.online) and not bool(self.session.offline)

    def _take_desk(self) -> bool:
        """The connected desk becomes the show's desk: its record, and its image for offline."""
        book = self.scenes.book
        if not self._live() or not deskimage.record_ready(self.store, book):
            return False
        name = str(self.config.get("console_name", "") or "")
        self._write_record(deskimage.record(self.store, book, name))
        image = deskimage.capture(self.store, self.recorder)
        if image is not None:
            self._write_desk_files(deskimage.pack(image))
        return True

    # -- the show, collected and installed ------------------------------------
    def _engine_settings(self):
        engine = self.waves._engine()
        return engine.s if engine is not None else None

    def collect(self) -> dict:
        """The working show as a show file's `show.json` holds it (no desk image)."""
        waves = dict(self.config.get("waves", {}) or {})
        ltc = dict(self.config.get("ltc", {}) or {})
        feats = dict(self.config.get("features", {}) or {})
        s = self._engine_settings()
        racks = copy.deepcopy({k: (s.data if s is not None else RACK_DEFAULTS).get(k, RACK_DEFAULTS[k])
                               for k in RACK_KEYS})
        cb = self.cues.book
        return {
            "format": FORMAT, "version": VERSION,
            "settings": {"features": {n: bool(feats.get(n, True)) for n in FEATURES},
                         "waves": {k: waves[k] for k in WAVES_KEYS if k in waves},
                         "ltc": {k: ltc[k] for k in LTC_KEYS if k in ltc},
                         "rig": {k: ltc[k] for k in RIG_KEYS if k in ltc}},
            "racks": racks,
            "cues": copy.deepcopy({"version": 1, "span": int(cb.span), "names": dict(cb.names),
                                   "groups": list(cb.groups), "cues": list(cb.cues)}),
            "macros": copy.deepcopy({"version": 2, "macros": list(self.macros.book.macros)}),
            "desk": copy.deepcopy(self._record),
        }

    def _fingerprint(self) -> str:
        show = self.collect()
        show.pop("desk", None)
        return hashlib.sha1(json.dumps(show, sort_keys=True, default=str).encode()).hexdigest()

    def _mark_saved(self) -> None:
        self._saved_print = self._fingerprint()
        self.config.set("show_print", self._saved_print)
        self.config.save()
        if self._modified:
            self._modified = False
            self.modifiedChanged.emit()

    def install(self, show: dict, desk_files: dict[str, bytes] | None) -> None:
        """Make `show` the working show: write its parts where each engine keeps them, and have
        every engine read them again."""
        settings = show.get("settings") or {}
        feats = settings.get("features") or {}
        self.config.set("features", {n: bool(feats.get(n, True)) for n in FEATURES})
        waves = dict(self.config.get("waves", {}) or {})
        waves.update({k: v for k, v in (settings.get("waves") or {}).items() if k in WAVES_KEYS})
        self.config.set("waves", waves)
        ltc = dict(self.config.get("ltc", {}) or {})
        ltc.update({k: v for k, v in (settings.get("ltc") or {}).items() if k in LTC_KEYS})
        rig = settings.get("rig") or {}
        device = str(rig.get("device") or "")
        if device and (device == "auto" or any(d.get("raw") == device for d in audio.inputs())):
            ltc["device"] = device
            if "channel" in rig:
                ltc["channel"] = rig["channel"]
        self.config.set("ltc", ltc)
        self.config.save()

        racks = show.get("racks") or {}
        s = self._engine_settings()
        if s is not None:
            keep = {k: s.data.get(k, RACK_DEFAULTS[k]) for k in RACK_MACHINE}
            s.data = copy.deepcopy(RACK_DEFAULTS)
            s.data.update({k: copy.deepcopy(v) for k, v in racks.items() if k in RACK_KEYS})
            s.data.update(keep)
            s.data["card"] = str(waves.get("card") or "PY")
            s.data["card_base"] = int(waves.get("card_base") or 0)
            s.save()
            s.load()

        macros = show.get("macros") or {"version": 2, "macros": []}
        cues = show.get("cues") or {"version": 1, "cues": []}
        _write_atomic(Path(self.macros.book.path), _json_bytes(macros))
        _write_atomic(Path(self.cues.book.path), _json_bytes(cues))
        self.macros.reload_book()                # macros first: cues point at them
        self.cues.reload_book()

        self._write_record(show.get("desk") or {})
        if desk_files is not None:
            self._write_desk_files(desk_files)

        self.features.boot()
        self.features.changed.emit()
        self.waves._tables_due = True
        self.waves.changed.emit()
        self.waves.tablesChanged.emit()
        self._issues = []
        self.issuesChanged.emit()
        self._check_due = True
        self._in_step = False
        if self.session.offline:
            self.session.connectNow()            # the new show's desk in place of the old

    # -- file actions ---------------------------------------------------------
    def _set_path(self, path: str) -> None:
        self.config.set("show_path", str(path))
        recent = [p for p in (self.config.get("show_recent", []) or []) if p != str(path)]
        if path:
            recent.insert(0, str(path))
        self.config.set("show_recent", recent[:RECENT])
        self.config.save()
        self.changed.emit()

    @staticmethod
    def _local(path_or_url: str) -> Path:
        text = str(path_or_url or "")
        if text.startswith("file:"):
            text = QUrl(text).toLocalFile()
        return Path(text).expanduser()

    @Slot(str, result=bool)
    def saveAs(self, path_or_url: str) -> bool:
        path = self._local(path_or_url)
        if not path.name:
            return False
        if path.suffix.lower() != SUFFIX:
            path = path.with_name(path.name + SUFFIX)
        self.cues.book.save()
        self.macros.book.save()
        if self._live() and not self._issues:
            self._take_desk()                    # the desk as it is now, if it is in step
        show = self.collect()
        show["name"] = path.stem
        show["saved"] = time.strftime("%Y-%m-%d %H:%M")
        show["app"] = __version__
        try:
            write_show(path, show, self._desk_files())
        except OSError as exc:
            self.notice.emit(f"Not saved: {exc.strerror or exc}", "bad")
            return False
        self._set_path(str(path))
        self._mark_saved()
        self.notice.emit(f"Saved {path.name}", "")
        return True

    @Slot(result=bool)
    def save(self) -> bool:
        """Into the show file it came from. False when it has none yet (the window asks)."""
        path = str(self.config.get("show_path", "") or "")
        if not path:
            return False
        return self.saveAs(path)

    @Slot(str, result=bool)
    def open(self, path_or_url: str) -> bool:
        path = self._local(path_or_url)
        try:
            show, desk = read_show(path)
        except ValueError as exc:
            self.notice.emit(f"{path.name}: {exc}", "bad")
            if str(exc) == "File not found":
                self._forget_recent(str(path))
            return False
        self.install(show, desk)
        self._set_path(str(path))
        self._mark_saved()
        self.notice.emit(f"Opened {path.name}", "")
        return True

    @Slot()
    def newShow(self) -> None:
        """An empty show. The desk connected now (if any) is its desk."""
        self.install(empty_show(), {})
        self._set_path("")
        self._take_desk()
        self._mark_saved()
        self.notice.emit("New show", "")

    def _forget_recent(self, path: str) -> None:
        self.config.set("show_recent", [p for p in (self.config.get("show_recent", []) or [])
                                         if p != path])
        self.config.save()
        self.changed.emit()

    @Slot(str)
    def forgetRecent(self, path: str) -> None:
        self._forget_recent(str(path))

    # -- the desk check -------------------------------------------------------
    def _online(self) -> None:
        self._check_due = True
        self._in_step = False

    def _gone(self) -> None:
        self._in_step = False

    def _scenes_moved(self) -> None:
        if self._live():
            self._check_due = True

    def _tick(self) -> None:
        now = self._fingerprint()
        modified = now != self._saved_print
        if modified != self._modified:
            self._modified = modified
            self.modifiedChanged.emit()
        if self._check_due and self._live() and not self._issues:
            self._check()

    def _check(self) -> None:
        book = self.scenes.book
        if not deskimage.record_ready(self.store, book):
            return                               # the desk is still being read: next second
        self._check_due = False
        name = str(self.config.get("console_name", "") or "")
        now = deskimage.record(self.store, book, name)
        issues = mismatch.find(self.collect(), self._record, now, self.scenes._bank)
        if issues:
            self._issues = issues
            self.issuesChanged.emit()
            return
        if not self._in_step or now != self._record:
            self._take_desk()
        self._in_step = True

    @Slot("QVariantMap")
    def resolve(self, choices: dict) -> None:
        """Apply the answers ({issue id: option}) and take the desk as the show's."""
        if not self._issues:
            return
        show = self.collect()
        changed = mismatch.resolve(show, self._issues, dict(choices or {}), self.scenes._bank)
        if changed:
            self.cues.book.save()
            self.macros.book.save()
            s = self._engine_settings()
            if s is not None:
                for key in ("map", "snap_map", "snap_skip"):
                    s.data[key] = show["racks"].get(key, s.data[key])
                s.save()
            _write_atomic(Path(self.macros.book.path), _json_bytes(show["macros"]))
            _write_atomic(Path(self.cues.book.path), _json_bytes(show["cues"]))
            self.macros.reload_book()
            self.cues.reload_book()
            self.waves._tables_due = True
            self.waves.changed.emit()
            self.waves.tablesChanged.emit()
        self._issues = []
        self.issuesChanged.emit()
        self._take_desk()
        self._in_step = True
        self.notice.emit(f"{changed} reference{'' if changed == 1 else 's'} updated"
                         if changed else "Show kept as it is", "")

    @Slot()
    def later(self) -> None:
        """Not now: nothing changes, and the desk is not taken as the show's -- so the same
        question comes back at the next connect."""
        self._issues = []
        self.issuesChanged.emit()
        self._in_step = False

    # -- what the window reads ------------------------------------------------
    def _path(self) -> str:
        return str(self.config.get("show_path", "") or "")

    def _name(self) -> str:
        path = self._path()
        return Path(path).stem if path else "Untitled show"

    def _recent(self) -> list:
        return [{"path": p, "name": Path(p).stem, "folder": str(Path(p).parent)}
                for p in (self.config.get("show_recent", []) or []) if p]

    def _desk(self) -> dict:
        r = self._record
        scenes = r.get("scenes") or []
        return {"known": bool(r), "name": str(r.get("name") or ""),
                "firmware": str(r.get("firmware") or ""),
                "captured": str(r.get("captured") or ""),
                "scenes": len(scenes),
                "scenesA": len([s for s in scenes if int(s.get("bank", 0)) == 0]),
                "scenesB": len([s for s in scenes if int(s.get("bank", 0)) == 1]),
                "channels": len(r.get("channels") or {}),
                "image": self._desk_zip.exists()}

    name = Property(str, _name, notify=changed)
    path = Property(str, _path, notify=changed)
    folder = Property(str, lambda self: str(Path(self._path()).parent) if self._path() else "",
                      notify=changed)
    recent = Property("QVariantList", _recent, notify=changed)
    # For the file dialogs: where the show file is, else Documents; and the file to suggest.
    folderUrl = Property(QUrl, lambda self: QUrl.fromLocalFile(
        str(Path(self._path()).parent) if self._path() else str(_documents())), notify=changed)
    fileUrl = Property(QUrl, lambda self: QUrl.fromLocalFile(
        self._path() or str(_documents() / ("Untitled show" + SUFFIX))), notify=changed)
    desk = Property("QVariantMap", _desk, notify=changed)
    modified = Property(bool, lambda self: self._modified, notify=modifiedChanged)
    issues = Property("QVariantList", lambda self: list(self._issues), notify=issuesChanged)
    suffix = Property(str, lambda self: SUFFIX, constant=True)
