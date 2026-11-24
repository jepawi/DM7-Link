"""TIMECODE -- LTC from an audio interface, and a cue list that recalls DM7 scenes or runs macros.

The panel's cue engine (`dm7gui.integrations.IntegrationsBridge`). A new cue is a scene cue;
choosing a macro makes it a macro cue. With the Macros part switched off a macro cue does
nothing (`AppMacros.start_macro` refuses). What that engine already guarantees is kept as it is --
a cue fires only when the timecode PLAYS THROUGH it, never on a locate (`ltc.crossed`); cues are
grouped in songs; the timeline draws one lane per hour; LIVE UPDATE moves cues to the incoming
timecode during a run.

The input is always an audio interface (`dm7link.audio`), on any channel it has.
"""
from __future__ import annotations

from PySide6.QtCore import Property, Signal, Slot

from dm7gui import ltc
from dm7gui.integrations import IntegrationsBridge

from . import audio

ltc.Reader.audio_factory = staticmethod(audio.open_audio)


class ShowCues(IntegrationsBridge):
    devicesChanged = Signal()

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        self._devices: list = []
        # This app reads an interface, never a GPIO pin: an old settings file says otherwise
        # only by accident.
        if str(self._get("input", "audio")) != "audio":
            self._store_setting("input", "audio")

    # -- a cue is a scene cue ------------------------------------------------
    @Slot(result=str)
    def addCue(self) -> str:
        cue_id = super().addCue()
        cue = self.book.find(cue_id) if cue_id else None
        if cue is not None:
            cue["kind"] = "scene"
            cue["name"] = ""
            self.book.save()
            self.cuesChanged.emit()
        return cue_id

    @Slot(str, str)
    def setCueMacro(self, cue_id: str, macro_id: str) -> None:
        """Choosing a macro makes the cue a macro cue (the scene it held is kept in the file)."""
        cue = self.book.find(str(cue_id))
        if cue is not None and macro_id:
            cue["kind"] = "macro"
        super().setCueMacro(cue_id, macro_id)

    def reload_book(self) -> None:
        """Another show's cue list and timecode settings, read again from their files."""
        from dm7gui.integrations import AUTO
        self.book.cues, self.book.groups, self.book.names = [], [], {}
        self.book.span = AUTO
        self.book.load()
        self._fired.clear()
        self._undo = {}
        self._pin = ""
        self._opened.clear()
        self._shut.clear()
        self._reload()
        self.reader.configure(self._cfg)
        self._forget_faults()
        self._forget_view()
        self._follow_points()
        self.settingsChanged.emit()
        self.cuesChanged.emit()

    @Slot(str)
    def addSong(self, name: str) -> None:
        self.book.add_group(str(name))
        self.book.save()
        self.cuesChanged.emit()

    # -- the input ------------------------------------------------------------
    @Slot(result="QVariantList")
    def audioInputs(self) -> list:
        self._devices = audio.inputs()
        self.devicesChanged.emit()
        return list(self._devices)

    @Slot()
    def rescanInputs(self) -> None:
        self.audioInputs()

    @Slot(str, "QVariant")
    def setOption(self, key: str, value) -> None:
        if str(key) == "channel":
            try:
                channel = max(1, min(64, int(value)))
            except (TypeError, ValueError):
                return
            self._store_setting("channel", channel)
            self.settingsChanged.emit()
            self.timecodeChanged.emit()
            return
        if str(key) == "device":
            self._store_setting("device", str(value) or "auto")
            if int(self._get("channel", 1)) > audio.channels_of(str(value)):
                self._store_setting("channel", 1)
            self.settingsChanged.emit()
            self.devicesChanged.emit()
            self.timecodeChanged.emit()
            return
        super().setOption(key, value)

    def _device_rows(self) -> list:
        if not self._devices:
            self._devices = audio.inputs()
        return list(self._devices)

    def _input_channels(self) -> int:
        device = str(self._get("device", "auto"))
        rows = self._device_rows()
        if device in ("", "auto"):
            hit = next((d for d in rows if d.get("default")), None)
        else:
            hit = next((d for d in rows if d["raw"] == device), None)
        return int(hit["channels"]) if hit else 2

    devices = Property("QVariantList", lambda self: self._device_rows(), notify=devicesChanged)
    inputChannels = Property(int, lambda self: self._input_channels(), notify=devicesChanged)
    audioAvailable = Property(bool, lambda self: audio.available(), constant=True)
