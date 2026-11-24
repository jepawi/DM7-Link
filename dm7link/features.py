"""Which parts of DM7 Link are in use: Waves, Timecode, Macros.

A part that is switched off is not only hidden -- it stops:

    waves      the SuperRack link closes (the rack bridge stops listening)
    timecode   the audio input closes; no cue fires (scene or macro)
    macros     every running macro stops and no trigger is watched. Switched back on, the
               triggers forget what they last saw, so nothing fires on what changed meanwhile.

Kept in config.json under `features`. Everything is on by default.
"""
from __future__ import annotations

from PySide6.QtCore import Property, QObject, Signal, Slot

from dm7gui.macros import MacrosBridge

NAMES = ("waves", "timecode", "macros")


class AppMacros(MacrosBridge):
    """The panel's macro engine, with a switch."""

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        self.active = True

    def set_active(self, on: bool) -> None:
        on = bool(on)
        if on == self.active:
            return
        self.active = on
        if on:
            self._when.forget()           # a fresh baseline: no edge from the time it was off
            self._clock.start()
        else:
            for run in list(self._runs.values()):
                run.stop()
            self._clock.stop()
        self.statusChanged.emit()
        self.listChanged.emit()

    def start_macro(self, macro_id: str, why: str) -> bool:
        if not self.active:
            return False
        return super().start_macro(macro_id, why)

    def reload_book(self) -> None:
        """Another show's macros: every run stops, the file is read again, nothing is open,
        and the triggers start from a fresh baseline."""
        from dm7gui.macros.model import names_used
        for run in list(self._runs.values()):
            run.stop()
        self.book.macros = []
        self.book.load()
        self._open = ""
        self._sel = ""
        self._caret = ":0"
        self._report = {}
        self._last.clear()
        for macro in self.book.macros:
            for name in names_used(macro):
                self.vars.declare(name)
        self._when.forget()
        self._meanings.invalidate()
        self.listChanged.emit()
        self.scriptChanged.emit()
        self.statusChanged.emit()
        self.problemsChanged.emit()


class Features(QObject):
    changed = Signal()

    def __init__(self, config, waves, cues, macros, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.config = config
        self.waves, self.cues, self.macros = waves, cues, macros

    def _get(self) -> dict:
        data = dict(self.config.get("features", {}) or {})
        return {n: bool(data.get(n, True)) for n in NAMES}

    def on(self, name: str) -> bool:
        return self._get().get(name, True)

    def boot(self) -> None:
        """Each part to its setting at start. The feature switch is the ONLY switch: Waves on
        means the SuperRack link is up, Timecode on means the audio input is open."""
        self._apply(self._get())

    def _apply(self, state: dict) -> None:
        if bool(self.waves.enabled) != state["waves"]:
            self.waves.setEnabled(state["waves"])
        if bool(self.cues.enabled) != state["timecode"]:
            self.cues.setEnabled(state["timecode"])
        if not state["macros"]:
            self.macros.stopAll()
        self.macros.set_active(state["macros"])

    @Slot(str, bool)
    def set(self, name: str, on: bool) -> None:
        if name not in NAMES:
            return
        data = self._get()
        data[name] = bool(on)
        self.config.set("features", data)
        self.config.save()
        self._apply(data)
        self.changed.emit()

    waves_on = Property(bool, lambda self: self.on("waves"), notify=changed)
    timecode_on = Property(bool, lambda self: self.on("timecode"), notify=changed)
    macros_on = Property(bool, lambda self: self.on("macros"), notify=changed)
    # QML names
    wavesOn = waves_on
    timecodeOn = timecode_on
    macrosOn = macros_on
