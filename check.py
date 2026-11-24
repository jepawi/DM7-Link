"""DM7 Link checks -- no console, no interface, no window.

    python3 check.py

1. LTC through the audio path: timecode is synthesised as 48 kHz PCM on input 2 of a stereo
   "interface", pushed through the same queue / edge finder the PortAudio callback feeds, and
   decoded by the panel's own decoder.
2. Scene cues fire without a macro engine, only when the timecode plays through them.
3. The app's QML loads (offscreen), when PySide6 can open a platform.
"""
from __future__ import annotations

import array
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from dm7link import paths  # noqa: E402

paths.install()

from dm7gui import ltc  # noqa: E402
from dm7link import audio  # noqa: E402

passed = failed = 0


def ok(cond, text):
    global passed, failed
    if cond:
        passed += 1
        print(f"ok    {text}")
    else:
        failed += 1
        print(f"FAIL  {text}")


# -- 1. LTC from samples -------------------------------------------------------
def pcm_for(first: ltc.Timecode, frames: int, rate: int = 48_000, level: int = 9000,
            channels: int = 2, pick: int = 1) -> bytes:
    """Biphase-mark LTC as interleaved int16, on channel `pick`; silence on the others."""
    fps = first.rate
    cell = 1.0 / (fps * ltc.BITS)
    edges = []
    at = 0.0
    tc = first
    for _ in range(frames):
        edges.extend(ltc.edge_times(ltc.frame_bits(tc), at, cell))
        at += 1.0 / fps
        tc = ltc.from_count(tc.count + 1, tc.rate, tc.drop)
    total = int(at * rate) + 1
    out = array.array("h", [0] * (total * channels))
    sign, e = 1, 0
    for n in range(total):
        t = n / rate
        while e < len(edges) and edges[e] <= t:
            sign = -sign
            e += 1
        out[n * channels + pick] = level * sign
    return out.tobytes()


got = []
lock = threading.Lock()
dec = ltc.Decoder("auto")


def sink(at):
    with lock:
        tc = dec.edge(at)
        if tc is not None:
            got.append(tc)


src = audio.PortAudioEdges(sink, "test", channel=2)
src._width, src._pick = 2, 1
data = pcm_for(ltc.Timecode(1, 2, 3, 0, rate=25), 50)
worker = threading.Thread(target=src._run, args=(48_000,), daemon=True)
worker.start()
block = 480 * 2 * 2
for i in range(0, len(data), block):
    src._callback(data[i:i + block], 480, None, None)
deadline = time.monotonic() + 5
while time.monotonic() < deadline and len(got) < 45:
    time.sleep(0.05)
src._stop.set()
ok(len(got) >= 45, f"decoded {len(got)} of 50 frames from input 2 of a stereo stream")
ok(bool(got) and got[0].text.startswith("01:02:0"), f"first frame reads {got[0].text if got else '-'}")
ok(all(b.count - a.count == 1 for a, b in zip(got, got[1:])), "frames arrive in order, none skipped")
ok(bool(got) and got[-1].rate == 25, "25 fps found without being told")

# input 1 of the same stream is silence: nothing decoded
got.clear()
dec = ltc.Decoder("auto")
src1 = audio.PortAudioEdges(sink, "test", channel=1)
src1._width, src1._pick = 2, 0
w1 = threading.Thread(target=src1._run, args=(48_000,), daemon=True)
w1.start()
for i in range(0, len(data), block):
    src1._callback(data[i:i + block], 480, None, None)
time.sleep(0.6)
src1._stop.set()
ok(not got, "the silent input decodes nothing")

ok(isinstance(audio.inputs(), list), f"inputs() answers ({'sounddevice' if audio.available() else 'no sounddevice'})")
if not audio.available():
    src2, why = audio.open_audio({"device": "auto", "channel": 1}, lambda at: None)
    ok(not src2.open and "sounddevice" in why.lower(), f"no PortAudio: says so ({why})")

# -- 2. scene cues without a macro engine ---------------------------------------
try:
    from PySide6.QtCore import QCoreApplication
    app = QCoreApplication.instance() or QCoreApplication([])
    from dm7gui.integrations import CueBook
    from dm7link.timecode import ShowCues
    import tempfile

    class Reader:
        rate, drop = 25, False

        def __init__(self):
            self.pos = None

        def position(self):
            return self.pos, self.pos is not None

        def timecode(self):
            return ltc.from_count(self.pos, 25) if self.pos is not None else None

        def snapshot(self):
            return {}

        def configure(self, s):
            pass

        def start(self):
            pass

        def stop(self):
            pass

    class Scenes:
        def __init__(self):
            self.calls = []
            from PySide6.QtCore import QObject, Signal

            class Sig(QObject):
                listChanged = Signal()
            self._sig = Sig()
            self.listChanged = self._sig.listChanged

            class Book:
                ready = False

                def find(self, n, bank=0):
                    return None

                def scenes(self, bank=0):
                    return []
            self.book = Book()

        def command(self, op, how, number=None, why=""):
            self.calls.append((op, how, number))
            return True, ""

    tmp = Path(tempfile.mkdtemp())
    reader, scenes = Reader(), Scenes()
    cues = ShowCues(reader=reader, macros=None, scenes=scenes, config=None, path=tmp / "cues.json")
    reader.pos = ltc.parse_tc("01:00:00:00", 25).count
    cid = cues.addCue()
    cue = cues.book.find(cid)
    ok(cue is not None and cue["kind"] == "scene", "a new cue is a scene cue")
    cues.setCueScene(cid, "12")
    cues.setCueAt(cid, "01:00:10:00")
    cues.armCue(cid, True)
    cues._seen = None
    for f in range(0, 9 * 25):                    # play 01:00:00 .. 01:00:09
        reader.pos = ltc.parse_tc("01:00:00:00", 25).count + f
        cues._cues()
    ok(scenes.calls == [], "nothing fires before the cue point")
    for f in range(9 * 25, 11 * 25):              # play through 01:00:10
        reader.pos = ltc.parse_tc("01:00:00:00", 25).count + f
        cues._cues()
    ok(len(scenes.calls) == 1 and scenes.calls[0][0] == "recall",
       f"playing through 01:00:10:00 recalls the scene once ({scenes.calls})")
    scenes.calls.clear()
    reader.pos = ltc.parse_tc("01:00:00:00", 25).count
    cues._cues()
    reader.pos = ltc.parse_tc("01:30:00:00", 25).count   # a locate past the cue
    cues._cues()
    ok(scenes.calls == [], "a locate past the cue fires nothing")
    cues.setCueScene(cid, "12.1")
    ok(cues.book.find(cid)["scene"] == "012.01", "a typed 12.1 is scene 12.01")
    cues.runCue(cid)
    ok(scenes.calls[-1:] == [("recall", "number", "012.01")],
       f"Run recalls exactly that scene ({scenes.calls[-1:]})")
    cues.shutdown()
except ImportError as exc:
    print(f"skip  cue checks ({exc})")

# -- 2b. a feature switched off stops, and comes back clean ----------------------
try:
    from dm7link.appconfig import AppConfig as Config
    from dm7gui.controls import ControlsBridge
    from dm7link.features import AppMacros, Features

    class FakeWaves:
        def __init__(self):
            self.enabled = True

        def setEnabled(self, on):
            self.enabled = bool(on)

    class FakeCues:
        def __init__(self):
            self.enabled = True

        def setEnabled(self, on):
            self.enabled = bool(on)

    ftmp = Path(tempfile.mkdtemp())
    fcfg = Config(ftmp / "config.json")
    fmacros = AppMacros(store=ControlsBridge().store, path=ftmp / "macros.json")
    fw, fc = FakeWaves(), FakeCues()
    feats = Features(fcfg, fw, fc, fmacros)
    feats.boot()
    ok(fw.enabled and fc.enabled and fmacros._clock.isActive(), "everything on by default")
    feats.set("waves", False)
    ok(not fw.enabled and not feats.wavesOn, "Waves off: the SuperRack link closes")
    feats.set("timecode", False)
    ok(not fc.enabled, "Timecode off: the input closes")
    feats.set("macros", False)
    ok(not fmacros._clock.isActive() and not fmacros.start_macro("x", "test"),
       "Macros off: no trigger is watched, nothing starts")
    feats.set("macros", True)
    ok(fmacros._clock.isActive(), "Macros back on: triggers are watched again")
    fcfg.set("superrack_adapter", "en7")
    fcfg.save()
    ok(Config(ftmp / "config.json").get("superrack_adapter") == "en7",
       "the SuperRack adapter choice survives a restart")
    ok(Config(ftmp / "config.json").get("features") == {"waves": False, "timecode": False,
                                                        "macros": True},
       "the switches are kept in config.json")
    feats2 = Features(Config(ftmp / "config.json"), FakeWaves(), FakeCues(), fmacros)
    feats2.boot()
    ok(not feats2.waves.enabled and not feats2.cues.enabled, "a restart keeps them off")
    fmacros.shutdown()
except ImportError as exc:
    print(f"skip  feature checks ({exc})")

# -- 3. the window loads ---------------------------------------------------------
env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
           DM7LINK_HOME=str(Path(__import__("tempfile").mkdtemp())))
run = subprocess.run([sys.executable, str(HERE / "run.py"), "--selftest", "--no-auto-connect"],
                     env=env, capture_output=True, text=True, timeout=60)
problems = [ln for ln in (run.stderr + run.stdout).splitlines()
            if ".qml:" in ln or "QML failed" in ln or "Traceback" in ln]
ok(run.returncode == 0 and not problems,
   "the window loads with no QML warnings" + ("" if not problems else ": " + problems[0]))

print(f"{passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
