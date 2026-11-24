"""LTC from an audio interface, on macOS, Windows and Linux.

The panel on the Pi reads its interface with `arecord`, which exists only on Linux. Here the
interface is opened through PortAudio (`sounddevice`), and everything after the samples is the
panel's own: `ltc.Crossings` finds the edges with hysteresis and interpolates each one between
two samples, and the reader's `Decoder` turns the intervals into timecode. An edge's time is its
place in the sample stream, so a late callback is only late -- the intervals are exact.

The PortAudio callback does one thing, put the block on a queue; a thread of ours finds the
edges. The callback is the thread that must never fall behind.

Settings used (the reader's `ltc` block):
    device    the interface's name as `inputs()` lists it; "auto" = the system default input
    channel   1-based input the LTC cable is in
"""
from __future__ import annotations

import array
import queue
import threading

from dm7gui import ltc

BLOCK_S = 0.01                   # 10 ms a callback


def _sd():
    try:
        import sounddevice
        return sounddevice
    except Exception:            # noqa: BLE001 -- missing package or no PortAudio library
        return None


def available() -> bool:
    return _sd() is not None


def inputs() -> list[dict]:
    """[{raw, label, channels}] -- every device that can record, default input first."""
    sd = _sd()
    if sd is None:
        return []
    try:
        devices = sd.query_devices()
        apis = sd.query_hostapis()
        default_in = sd.default.device[0] if sd.default.device else -1
    except Exception:            # noqa: BLE001
        return []
    out, seen = [], set()
    for index, dev in enumerate(devices):
        chans = int(dev.get("max_input_channels") or 0)
        if chans <= 0:
            continue
        name = str(dev.get("name") or f"Input {index}")
        api = str(apis[dev["hostapi"]]["name"]) if 0 <= dev.get("hostapi", -1) < len(apis) else ""
        # Windows lists one device under every host API (MME, DirectSound, WASAPI, WDM-KS):
        # one row per name, preferring the API the system default sits on.
        if name in seen:
            continue
        seen.add(name)
        out.append({"raw": name, "label": name, "channels": chans, "api": api,
                    "default": index == default_in})
    out.sort(key=lambda d: not d["default"])
    return out


def channels_of(device: str) -> int:
    for dev in inputs():
        if dev["raw"] == device:
            return int(dev["channels"])
    return 2


class PortAudioEdges(ltc.Edges):
    """Same face as `ltc.AudioEdges`: start / stop / open / error / name."""

    kind = "audio"

    def __init__(self, sink, device: str = "auto", channel: int = 1) -> None:
        super().__init__(0, sink, 0.0)
        self.device = str(device or "auto")
        self.channel = max(1, int(channel or 1))
        self.name = ""
        self._stream = None
        self._q: queue.Queue = queue.Queue(maxsize=400)    # 4 s of blocks
        self._thread: threading.Thread | None = None
        self._stop = threading.Event()
        self._width = 1
        self._pick = 0

    @property
    def open(self) -> bool:
        return self._stream is not None and bool(getattr(self._stream, "active", False))

    def _find(self, sd):
        if self.device in ("", "auto"):
            index = sd.default.device[0] if sd.default.device else None
            if index is None or index < 0:
                return None
            return index, sd.query_devices(index)
        for index, dev in enumerate(sd.query_devices()):
            if dev.get("name") == self.device and int(dev.get("max_input_channels") or 0) > 0:
                return index, dev
        return None

    def start(self) -> bool:
        sd = _sd()
        if sd is None:
            self.error = "Audio input needs sounddevice (pip install sounddevice)"
            return False
        hit = self._find(sd)
        if hit is None:
            self.error = ("no audio input" if self.device in ("", "auto")
                          else f"{self.device} not found")
            return False
        index, dev = hit
        have = int(dev.get("max_input_channels") or 1)
        if self.channel > have:
            self.error = f"{dev['name']} has {have} input{'s' if have != 1 else ''}"
            return False
        self.name = str(dev.get("name") or "")
        self._width = self.channel           # open as few channels as reach the one wanted
        self._pick = self.channel - 1
        rate = int(dev.get("default_samplerate") or ltc.AUDIO_RATE)
        try:
            self._stream = sd.RawInputStream(
                device=index, channels=self._width, samplerate=rate, dtype="int16",
                blocksize=max(64, int(rate * BLOCK_S)), callback=self._callback)
            self._stream.start()
        except Exception as exc:             # noqa: BLE001 -- busy, unplugged, refused
            self._stream = None
            self.error = str(exc).splitlines()[0] if str(exc) else "the audio input would not open"
            return False
        self._stop.clear()
        self._thread = threading.Thread(target=self._run, args=(rate,), name="dm7link-ltc",
                                        daemon=True)
        self._thread.start()
        self.error = ""
        return True

    def _callback(self, data, frames, _time, status) -> None:
        try:
            self._q.put_nowait(bytes(data))
        except queue.Full:
            pass

    def _run(self, rate: int) -> None:
        cross = ltc.Crossings(rate)
        width, pick = self._width, self._pick
        while not self._stop.is_set():
            try:
                chunk = self._q.get(timeout=0.25)
            except queue.Empty:
                if self._stream is not None and not getattr(self._stream, "active", True):
                    self.error = "the audio input closed"
                    return
                continue
            pcm = array.array("h")
            pcm.frombytes(chunk[: len(chunk) - len(chunk) % 2])
            for at in cross.feed(pcm[pick::width] if width > 1 else pcm):
                self.sink(at)

    def stop(self) -> None:
        self._stop.set()
        stream, self._stream = self._stream, None
        if stream is not None:
            try:
                stream.stop()
                stream.close()
            except Exception:                # noqa: BLE001
                pass
        thread, self._thread = self._thread, None
        if thread is not None and thread.is_alive():
            thread.join(timeout=1.0)


def open_audio(settings: dict, sink) -> tuple:
    """The reader's `audio_factory`: (the input, what went wrong). Never raises."""
    source = PortAudioEdges(sink, settings.get("device", "auto"), settings.get("channel", 1))
    try:
        if source.start():
            return source, ""
    except Exception as exc:                 # noqa: BLE001
        source.error = str(exc)
    return source, source.error or "the audio input would not open"
