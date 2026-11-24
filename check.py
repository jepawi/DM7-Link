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

# -- 2c. show files: the desk check on its own -----------------------------------
try:
    from dm7link import mismatch

    def show_with(cue_scenes, macro_scenes=(), snap=None, skip=(), rack_map=None, follow=True):
        return {"cues": {"cues": [{"id": f"c{i}", "kind": "scene", "scene": s, "armed": True}
                                  for i, s in enumerate(cue_scenes)]},
                "macros": {"macros": [{"id": "m1", "armed": True, "triggers": [],
                                       "blocks": [{"kind": "if", "then": [
                                           {"kind": "scene", "do": "recall", "scene": s}
                                           for s in macro_scenes], "else": []}]}]},
                "racks": {"snap_map": dict(snap or {}), "snap_skip": list(skip),
                          "map": dict(rack_map or {}), "follow_patch": follow}}

    def desk(*scenes, channels=None):
        return {"scenes": [{"bank": 0, "number": n, "title": t} for n, t in scenes],
                "channels": dict(channels or {})}

    was = desk(("010.00", "Band on"), ("012.00", "Band off"), ("020.00", "Interval"),
               ("030.00", "Encore"), channels={"CH 1": "Kick", "CH 2": "Snare"})
    now = desk(("011.00", "Band on"), ("012.00", "Speech"), ("020.00", "Interval"),
               channels={"CH 1": "Hat", "CH 2": "Snare top", "CH 3": "Kick"})
    show = show_with(["010.00", "020.00", "030.00", "040.00"], ["012.00"],
                     snap={"A 10": "Verse", "A 20": "Break"}, skip=["A 12"],
                     rack_map={"CH 1": "Kick rack", "CH 2": "Snare rack"}, follow=False)
    issues = mismatch.find(show, was, now, 0)
    by = {i["id"]: i for i in issues}
    ok(by.get("scene:0:010.00", {}).get("kind") == "moved"
       and by["scene:0:010.00"]["choice"] == "follow:011.00",
       "a scene renumbered on the desk is found by its title, and followed by default")
    ok(by.get("scene:0:012.00", {}).get("kind") == "renamed", "a re-titled scene is found")
    ok(by.get("scene:0:030.00", {}).get("kind") == "missing", "a deleted scene is found")
    ok(by.get("scene:0:040.00", {}).get("kind") == "missing",
       "a scene the show never saw and the desk does not have is found")
    ok("scene:0:020.00" not in by, "an unchanged scene is no issue")
    ok(by.get("channel:CH 1", {}).get("choice") == "follow:CH 3",
       "a channel whose name moved is followed to the channel that has it now")
    ok(by.get("channel:CH 2", {}).get("kind") == "renamed", "a renamed channel is found")
    n = mismatch.resolve(show, issues, {"scene:0:030.00": "clear"}, 0)
    cues_now = [c["scene"] for c in show["cues"]["cues"]]
    ok(cues_now == ["011.00", "020.00", "", "040.00"],
       f"resolving: cue followed, cue cleared, cue kept ({cues_now})")
    ok(show["cues"]["cues"][2]["armed"] is False, "a cue whose scene was removed is disarmed")
    ok(show["macros"]["macros"][0]["blocks"][0]["then"][0]["scene"] == "012.00",
       "a re-titled scene is kept by default")
    ok(show["racks"]["snap_map"] == {"A 11": "Verse", "A 20": "Break"},
       f"the Waves scene table follows too ({show['racks']['snap_map']})")
    ok(show["racks"]["map"] == {"CH 3": "Kick rack", "CH 2": "Snare rack"},
       f"the Waves rack table follows the channel ({show['racks']['map']})")
    ok(n == 4, f"four references changed: two cues, the Waves scene, the channel ({n})")
    ok(mismatch.find(show_with(["010.00"]), {}, desk(("010.00", "x")), 0) == [],
       "a show with no desk record: what is on the desk is fine")
    ok(mismatch.find(show_with([], rack_map={"CH 1": "K"}), was, now, 0) == [],
       "with Follow SuperRack's patch on, channels are not checked")
except ImportError as exc:
    print(f"skip  desk check ({exc})")

# -- 2d. show files: the desk image and the file itself ------------------------
try:
    from dm7gui.controls import ControlsBridge
    from dm7link import deskimage, showfile

    blank = deskimage.blank()
    ok(blank is not None and len(blank["stream"]) > 1_000_000, "the blank DM7 ships with the app")
    store = ControlsBridge().store
    deskimage.AreaRecorder(store)
    ok(deskimage.replay(store, blank) >= 10, "the blank DM7 replays as a console")
    idx = store.leaf_index("Mixing", ["InputChannel", "Label", "Name"])
    store.mirror.seed("Mixing", idx, [4] + [0] * (len(idx) - 1), "Vox")
    image = deskimage.capture(store, None)
    files = deskimage.pack(image)
    again = ControlsBridge().store
    deskimage.replay(again, deskimage.unpack(files))
    ok(again.raw_at("Mixing", idx, [4] + [0] * (len(idx) - 1)) == "Vox",
       "a change made after the sync survives the image")
    ok(sum(len(b) for b in files.values()) < 200_000,
       f"the image is small ({sum(len(b) for b in files.values()):,} bytes)")

    stmp = Path(tempfile.mkdtemp())
    s = showfile.empty_show()
    s["cues"]["cues"] = [{"id": "c1", "scene": "001.00", "kind": "scene"}]
    showfile.write_show(stmp / "a.dm7show", s, files)
    back, desk_back = showfile.read_show(stmp / "a.dm7show")
    ok(back["cues"]["cues"][0]["scene"] == "001.00" and "desk/stream.bin" in desk_back,
       "a show file reads back with its desk")
    (stmp / "b.dm7show").write_text("{}")
    try:
        showfile.read_show(stmp / "b.dm7show")
        ok(False, "a file that is not a show is refused")
    except ValueError:
        ok(True, "a file that is not a show is refused")
except ImportError as exc:
    print(f"skip  desk image ({exc})")

# -- 2e. show files in the running app: save, desk changes, resolve, offline -----
try:
    from dm7gui.mock import DEMO_SETTINGS
    if not DEMO_SETTINGS.exists():
        raise ImportError("no recorded console in this checkout")
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    from PySide6.QtCore import QCoreApplication
    from PySide6.QtGui import QGuiApplication
    from dm7gui.channels import ChannelsBridge
    from dm7gui.controls import ControlsBridge
    from dm7gui.scenes import SceneBridge
    from dm7gui.waves import WavesBridge
    from dm7link.appconfig import AppConfig
    from dm7link.features import AppMacros, Features
    from dm7link.offline import LinkConnection, LinkWorker
    from dm7link.showfile import ShowFiles
    from dm7link.timecode import ShowCues

    qapp = QGuiApplication.instance() or QGuiApplication([])

    def wait(cond, seconds=20.0):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            QCoreApplication.processEvents()
            if cond():
                return True
            time.sleep(0.02)
        return False

    atmp = Path(tempfile.mkdtemp())
    acfg = AppConfig(atmp / "config.json")
    acfg.set("features", {"waves": False, "timecode": False, "macros": True})
    acfg.set("waves", dict(acfg.get("waves"), link="direct"))
    acfg.save()
    controls = ControlsBridge()
    box = {}
    worker = LinkWorker(warmup=0.2, mode="ok", demo=True, meter_mode="off",
                        value_store=controls.store, image_source=lambda: box["show"].image())
    channels = ChannelsBridge(store=controls.store, meters=None)
    session = LinkConnection(config=acfg, worker=worker, controls=controls, extras=[channels])
    controls.bind(session)
    channels.bind(session)
    scenes = SceneBridge(store=controls.store)
    scenes.bind(session)
    areader = ltc.Reader(acfg.get("ltc"))
    amacros = AppMacros(store=controls.store, ltc=areader, scenes=scenes, path=atmp / "macros.json")
    amacros.bind(session)
    acues = ShowCues(reader=areader, macros=amacros, scenes=scenes, config=acfg,
                     path=atmp / "cues.json")
    awaves = WavesBridge(channels=channels, config=acfg, scenes=scenes)
    afeats = Features(acfg, awaves, acues, amacros)
    show = ShowFiles(atmp, acfg, session, scenes, awaves, acues, amacros, afeats, controls.store)
    box["show"] = show
    afeats.boot()
    session.setIp("10.0.0.7")
    session.connectNow()
    ok(wait(lambda: session.online), "the recorded console connects")
    ok(wait(lambda: show.desk["known"] and show.desk["scenesA"] == 12),
       f"connected, the desk is taken as the show's ({show.desk})")
    ok(not show.modified, "nothing to save yet")

    cid = acues.addCue()
    acues.setCueScene(cid, "10")                  # "Band on" in the recording
    ok(wait(lambda: show.modified, 3), "a new cue makes the show unsaved")
    path = atmp / "Tour.dm7show"
    ok(show.saveAs(str(path)) and path.exists() and not show.modified and show.name == "Tour",
       "SAVE AS writes the show file")

    # The desk the show was built on had "Band on" at 7: the connected one has it at 10.
    rec = dict(show._record)
    rec["scenes"] = [dict(sc, number="007.00") if sc["number"] == "010.00" else sc
                     for sc in rec["scenes"]]
    show._write_record(rec)
    acues.setCueScene(cid, "7")
    show._check_due = True
    ok(wait(lambda: len(show.issues) == 1, 5) and show.issues[0]["kind"] == "moved",
       f"a scene moved on the desk is asked about ({show.issues})")
    show.resolve({})
    ok(acues.book.find(cid)["scene"] == "010.00" and not show.issues,
       "APPLY follows the cue to the scene's new number")

    acues.setCueScene(cid, "7")
    show.later()
    show._check_due = True
    ok(wait(lambda: len(show.issues) == 1, 5), "...and asked again")
    show.later()
    ok(acues.book.find(cid)["scene"] == "007.00", "LATER changes nothing")

    ok(show.open(str(path)) and acues.book.find(cid)["scene"] == "010.00",
       "OPEN puts the saved show back")
    acues.addCue()
    show.newShow()
    ok(acues.cueCount == 0 and show.name == "Untitled show", "NEW empties the show")
    show.open(str(path))

    session.setOffline(True)
    ok(wait(lambda: session.online and session.offline and session.offlineFrom == "show"),
       "offline: the show's own desk stands in for the console")
    ok(acfg.get("console_ip") == "10.0.0.7", "offline leaves the console address alone")
    show._check_due = True
    ok(not wait(lambda: show.issues, 1.5), "offline, the desk check does not run")
    session.setOffline(False)
    ok(wait(lambda: session.online and not session.offline), "back online to the console")
    session.shutdown()
    amacros.shutdown()
    acues.shutdown()
    awaves.shutdown()
except ImportError as exc:
    print(f"skip  show files in the app ({exc})")

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
